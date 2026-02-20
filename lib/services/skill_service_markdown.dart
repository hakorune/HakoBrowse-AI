part of 'skill_service.dart';

_ParsedSkill _parseSkill(String text) {
  final lines = text.replaceAll('\r\n', '\n').split('\n');
  if (lines.isEmpty || lines.first.trim() != '---') {
    return _ParsedSkill(frontmatter: <String, dynamic>{}, body: text.trim());
  }
  final out = <String, dynamic>{};
  final bodyLines = <String>[];
  String? activeListKey;
  var inFrontmatter = true;

  for (var i = 1; i < lines.length; i++) {
    final line = lines[i];
    if (inFrontmatter && line.trim() == '---') {
      inFrontmatter = false;
      continue;
    }

    if (!inFrontmatter) {
      bodyLines.add(line);
      continue;
    }

    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    if (trimmed.startsWith('#')) continue;

    if (trimmed.startsWith('- ')) {
      if (activeListKey != null) {
        final rawValue = trimmed.substring(2).trim();
        final next = (out[activeListKey] as List<String>?) ?? <String>[];
        next.add(_trimQuote(rawValue));
        out[activeListKey] = next;
      }
      continue;
    }

    final idx = line.indexOf(':');
    if (idx <= 0) continue;
    final key = line.substring(0, idx).trim();
    final value = line.substring(idx + 1).trim();
    if (value.isEmpty) {
      out[key] = <String>[];
      activeListKey = key;
      continue;
    }
    if (value.startsWith('[') && value.endsWith(']')) {
      out[key] = _parseAllowedTools(value);
      activeListKey = null;
      continue;
    }
    out[key] = _trimQuote(value);
    activeListKey = null;
  }

  final body = bodyLines.join('\n').trim();
  return _ParsedSkill(frontmatter: out, body: body);
}

String _buildSkillMarkdown({
  required String name,
  required String description,
  required List<String> allowedTools,
  required String body,
}) {
  final buffer = StringBuffer()
    ..writeln('---')
    ..writeln('name: ${_yamlQuote(name)}')
    ..writeln('description: ${_yamlQuote(description)}');
  if (allowedTools.isEmpty) {
    buffer.writeln('allowedTools: []');
  } else {
    final encoded = allowedTools.map(_yamlQuote).join(', ');
    buffer.writeln('allowedTools: [$encoded]');
  }
  buffer.writeln('---');
  if (body.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln(body);
  }
  return buffer.toString();
}

String _slugify(String value) {
  final lower = value.trim().toLowerCase();
  final replaced = lower
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return replaced;
}

String _yamlQuote(String value) {
  return jsonEncode(value);
}

String _trimQuote(String value) {
  final trimmed = value.trim();
  if (trimmed.length >= 2 &&
      ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
          (trimmed.startsWith("'") && trimmed.endsWith("'")))) {
    return trimmed.substring(1, trimmed.length - 1).trim();
  }
  return trimmed;
}

List<String> _parseAllowedTools(Object? raw) {
  if (raw == null) return <String>[];
  if (raw is List) {
    return raw
        .map((s) => _trimQuote(s.toString()))
        .where((s) => s.isNotEmpty)
        .toList();
  }
  final text = raw.toString().trim();
  if (text.isEmpty) return <String>[];
  var listText = text;
  if (listText.startsWith('[') && listText.endsWith(']')) {
    listText = listText.substring(1, listText.length - 1);
  }
  return listText
      .split(',')
      .map((s) => _trimQuote(s))
      .where((s) => s.isNotEmpty)
      .toList();
}

String _basename(String path) {
  final normalized = path.replaceAll('\\', '/');
  final idx = normalized.lastIndexOf('/');
  if (idx < 0 || idx + 1 >= normalized.length) return normalized;
  return normalized.substring(idx + 1);
}

class _ParsedSkill {
  final Map<String, dynamic> frontmatter;
  final String body;

  const _ParsedSkill({
    required this.frontmatter,
    required this.body,
  });
}
