part of '../tool_executor.dart';

List<SkillDefinition> _skillSource(List<SkillDefinition> skills) {
  final enabledSkills = skills.where((s) => s.enabled).toList(growable: false);
  return enabledSkills.isNotEmpty ? enabledSkills : skills;
}

List<_BookmarkLinkEntry> _flattenLinksWithPath(List<BookmarkNode> nodes) {
  final out = <_BookmarkLinkEntry>[];

  void walk(List<BookmarkNode> items, List<String> path) {
    for (final node in items) {
      if (node.isFolder) {
        walk(node.children, [...path, node.displayTitle]);
        continue;
      }
      out.add(_BookmarkLinkEntry(node: node, path: path.join(' / ')));
    }
  }

  walk(nodes, const <String>[]);
  return out;
}

Future<List<String>> _listSkillFiles(
  Directory skillDir, {
  int maxFiles = 120,
}) async {
  final out = <String>[];
  final rootPath = skillDir.absolute.path;
  final rootNorm = rootPath.replaceAll('\\', '/');

  await for (final entity in skillDir.list(recursive: true)) {
    if (entity is! File) continue;
    final normalized = entity.absolute.path.replaceAll('\\', '/');
    if (!normalized.startsWith(rootNorm)) continue;
    var relative = normalized.substring(rootNorm.length);
    if (relative.startsWith('/')) {
      relative = relative.substring(1);
    }
    if (relative.isEmpty) continue;
    out.add(relative);
    if (out.length >= maxFiles) break;
  }

  out.sort((a, b) => a.compareTo(b));
  return out;
}

(String?, File?, String?) _resolveSkillFile({
  required Directory skillDir,
  required String requestedPath,
}) {
  final normalized = requestedPath.replaceAll('\\', '/').trim();
  if (normalized.isEmpty) {
    return ('file_path is required', null, null);
  }
  if (normalized.startsWith('/') ||
      normalized.startsWith('\\') ||
      RegExp(r'^[a-zA-Z]:').hasMatch(normalized)) {
    return (
      'file_path must be a relative path inside the skill folder',
      null,
      null
    );
  }
  final segments = normalized.split('/');
  if (segments.any((s) => s == '..')) {
    return ('file_path cannot contain ".."', null, null);
  }

  final rootPath = skillDir.absolute.path;
  final file = File('${skillDir.path}/$normalized');
  final targetPath = file.absolute.path;
  if (!_pathStartsWith(targetPath, rootPath)) {
    return ('file_path points outside the skill folder', null, null);
  }

  final relative = _relativePath(rootPath: rootPath, targetPath: targetPath);
  return (null, file, relative);
}

bool _pathStartsWith(String targetPath, String rootPath) {
  final target = targetPath.replaceAll('\\', '/').toLowerCase();
  final root = rootPath.replaceAll('\\', '/').toLowerCase();
  if (target == root) return true;
  return target.startsWith('$root/');
}

String _relativePath({
  required String rootPath,
  required String targetPath,
}) {
  final root = rootPath.replaceAll('\\', '/');
  final target = targetPath.replaceAll('\\', '/');
  if (target == root) return '';
  if (target.startsWith('$root/')) {
    return target.substring(root.length + 1);
  }
  return target;
}

ToolAuthProfile? _findAuthProfile(
  List<ToolAuthProfile> profiles,
  String key,
) {
  final normalized = key.trim().toLowerCase();
  if (normalized.isEmpty) return null;

  for (final profile in profiles) {
    if (profile.id.toLowerCase() == normalized) return profile;
  }
  for (final profile in profiles) {
    if (profile.name.toLowerCase() == normalized) return profile;
  }
  for (final profile in profiles) {
    if (profile.name.toLowerCase().contains(normalized)) return profile;
  }
  return null;
}

bool _headerExistsIgnoreCase(
  Map<String, String> headers,
  String key,
) {
  final lower = key.toLowerCase();
  for (final existing in headers.keys) {
    if (existing.toLowerCase() == lower) return true;
  }
  return false;
}

bool _isHostAllowed(String host, List<String> allowedHosts) {
  final lowerHost = host.trim().toLowerCase();
  if (lowerHost.isEmpty) return false;
  for (final raw in allowedHosts) {
    final allowed = raw.trim().toLowerCase();
    if (allowed.isEmpty) continue;
    if (allowed.startsWith('*.')) {
      final suffix = allowed.substring(2);
      if (suffix.isEmpty) continue;
      if (lowerHost == suffix || lowerHost.endsWith('.$suffix')) {
        return true;
      }
      continue;
    }
    if (lowerHost == allowed) return true;
  }
  return false;
}

Map<String, String> _redactHeaders(Map<String, String> headers) {
  const sensitive = <String>{
    'authorization',
    'proxy-authorization',
    'cookie',
    'set-cookie',
    'x-api-key',
  };
  final out = <String, String>{};
  headers.forEach((key, value) {
    final lower = key.toLowerCase();
    if (sensitive.contains(lower)) {
      out[key] = '[REDACTED]';
    } else {
      out[key] = value;
    }
  });
  return out;
}

SkillDefinition? _findSkill(
  List<SkillDefinition> skills, {
  String? skillId,
  String? skillName,
  String? query,
}) {
  final id = skillId?.toLowerCase();
  if (id != null && id.isNotEmpty) {
    for (final skill in skills) {
      if (skill.id.toLowerCase() == id) return skill;
    }
  }

  final name = skillName?.toLowerCase();
  if (name != null && name.isNotEmpty) {
    for (final skill in skills) {
      if (skill.name.toLowerCase() == name) return skill;
    }
    for (final skill in skills) {
      if (skill.name.toLowerCase().contains(name)) return skill;
    }
  }

  final q = query?.toLowerCase();
  if (q != null && q.isNotEmpty) {
    final scored = skills
        .map((skill) => (skill: skill, score: _scoreSkill(skill, q)))
        .where((entry) => entry.score > 0)
        .toList(growable: false)
      ..sort((a, b) => b.score.compareTo(a.score));
    if (scored.isNotEmpty) {
      return scored.first.skill;
    }
  }

  if (skills.length == 1) {
    return skills.first;
  }
  return null;
}

int _scoreSkill(SkillDefinition skill, String query) {
  var score = 0;
  final id = skill.id.toLowerCase();
  final name = skill.name.toLowerCase();
  final desc = skill.description.toLowerCase();
  if (id == query) score += 120;
  if (name == query) score += 120;
  if (id.contains(query)) score += 60;
  if (name.contains(query)) score += 80;
  if (desc.contains(query)) score += 30;
  return score;
}

({
  String content,
  bool truncated,
  String mode,
  int? startLine,
  int? endLine,
  int totalLines,
}) _extractSkillSnippet({
  required SkillDefinition skill,
  required String? section,
  required String? query,
  required int? startLine,
  required int? endLine,
  required int maxChars,
}) {
  final body = skill.body;
  final totalLines = _countLines(body);
  if (body.trim().isEmpty) {
    return (
      content: '',
      truncated: false,
      mode: 'empty',
      startLine: null,
      endLine: null,
      totalLines: totalLines,
    );
  }

  String selected = body;
  String mode = 'full';
  int? effectiveStartLine;
  int? effectiveEndLine;

  final hasLineRange = (startLine != null) || (endLine != null);
  if (hasLineRange) {
    final byRange = _extractLineRange(
      body,
      startLine: startLine,
      endLine: endLine,
    );
    selected = byRange.content;
    effectiveStartLine = byRange.startLine;
    effectiveEndLine = byRange.endLine;
    mode = 'line_range';
  }

  final sectionName = section?.trim().toLowerCase();
  if (!hasLineRange && sectionName != null && sectionName.isNotEmpty) {
    final bySection = _extractSectionByHeading(body, sectionName);
    if (bySection.trim().isNotEmpty) {
      selected = bySection.trim();
      mode = 'section';
    }
  }

  final queryText = query?.trim().toLowerCase();
  if (queryText != null && queryText.isNotEmpty) {
    final queryHit = selected.toLowerCase().contains(queryText);
    final byQuery = _extractWindowByQuery(selected, queryText, maxChars);
    if (byQuery.trim().isNotEmpty) {
      selected = byQuery.trim();
      if (queryHit) {
        mode = mode == 'full' ? 'query_window' : '$mode+query';
      }
    }
  }

  if (selected.length <= maxChars) {
    return (
      content: selected,
      truncated: false,
      mode: mode,
      startLine: effectiveStartLine,
      endLine: effectiveEndLine,
      totalLines: totalLines,
    );
  }
  return (
    content: '${selected.substring(0, maxChars)}\n...',
    truncated: true,
    mode: mode,
    startLine: effectiveStartLine,
    endLine: effectiveEndLine,
    totalLines: totalLines,
  );
}

({
  String content,
  int startLine,
  int endLine,
}) _extractLineRange(
  String text, {
  required int? startLine,
  required int? endLine,
}) {
  final normalized = text.replaceAll('\r\n', '\n');
  final lines = normalized.split('\n');
  final totalLines = lines.length;
  if (totalLines == 0) {
    return (content: '', startLine: 0, endLine: 0);
  }

  var start = startLine ?? 1;
  var end = endLine ?? totalLines;
  if (start < 1) start = 1;
  if (start > totalLines) start = totalLines;
  if (end < start) end = start;
  if (end > totalLines) end = totalLines;

  final content = lines.sublist(start - 1, end).join('\n');
  return (
    content: content,
    startLine: start,
    endLine: end,
  );
}

String _extractSectionByHeading(String markdown, String sectionName) {
  final lines = markdown.replaceAll('\r\n', '\n').split('\n');
  var start = -1;
  var end = lines.length;
  final heading = RegExp(r'^\s{0,3}(#{1,6})\s+(.+?)\s*$');
  int? startLevel;

  for (var i = 0; i < lines.length; i++) {
    final match = heading.firstMatch(lines[i]);
    if (match == null) continue;
    final level = match.group(1)?.length ?? 1;
    final text = (match.group(2) ?? '').toLowerCase();
    if (start < 0) {
      if (text.contains(sectionName)) {
        start = i;
        startLevel = level;
      }
      continue;
    }
    if (startLevel != null && level <= startLevel) {
      end = i;
      break;
    }
  }

  if (start < 0) return '';
  return lines.sublist(start, end).join('\n').trim();
}

String _extractWindowByQuery(String text, String query, int maxChars) {
  final lower = text.toLowerCase();
  final idx = lower.indexOf(query);
  if (idx < 0 || text.length <= maxChars) return text;

  var start = idx - (maxChars ~/ 3);
  if (start < 0) start = 0;
  var end = start + maxChars;
  if (end > text.length) {
    end = text.length;
    final shifted = end - maxChars;
    start = shifted < 0 ? 0 : shifted;
  }

  final prevBreak = text.lastIndexOf('\n', start);
  if (prevBreak >= 0) start = prevBreak + 1;
  final nextBreak = text.indexOf('\n', end);
  if (nextBreak >= 0) end = nextBreak;

  if (start >= end) {
    final limit = maxChars < text.length ? maxChars : text.length;
    return text.substring(0, limit);
  }
  return text.substring(start, end).trim();
}

int _countLines(String text) {
  if (text.isEmpty) return 0;
  return '\n'.allMatches(text).length + 1;
}

List<Map<String, dynamic>> _extractHeadings(
  String markdown, {
  required int maxHeadings,
}) {
  final lines = markdown.replaceAll('\r\n', '\n').split('\n');
  final heading = RegExp(r'^\s{0,3}(#{1,6})\s+(.+?)\s*$');
  final markers = <({int level, String title, int startLine})>[];

  for (var i = 0; i < lines.length; i++) {
    final match = heading.firstMatch(lines[i]);
    if (match == null) continue;
    final level = match.group(1)?.length ?? 1;
    final title = (match.group(2) ?? '').trim();
    if (title.isEmpty) continue;
    markers.add((
      level: level,
      title: title,
      startLine: i + 1,
    ));
  }

  final out = <Map<String, dynamic>>[];
  for (var i = 0; i < markers.length; i++) {
    final marker = markers[i];
    var endLine = lines.length;
    for (var j = i + 1; j < markers.length; j++) {
      if (markers[j].level <= marker.level) {
        endLine = markers[j].startLine - 1;
        break;
      }
    }
    if (endLine < marker.startLine) {
      endLine = marker.startLine;
    }
    out.add({
      'level': marker.level,
      'title': marker.title,
      'start_line': marker.startLine,
      'end_line': endLine,
      'line_count': endLine - marker.startLine + 1,
    });
    if (out.length >= maxHeadings) break;
  }
  return out;
}

class _BookmarkLinkEntry {
  final BookmarkNode node;
  final String path;

  const _BookmarkLinkEntry({required this.node, required this.path});
}
