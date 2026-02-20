part of '../tool_executor.dart';

String _handleLoadSkillIndexTool({
  required Map<String, dynamic> arguments,
  required List<SkillDefinition> skills,
}) {
  final source = _skillSource(skills);
  if (source.isEmpty) {
    return jsonEncode({'error': 'No skills available'});
  }

  final skillId = (arguments['skill_id'] as String?)?.trim();
  final skillName = (arguments['skill_name'] as String?)?.trim();
  final query = (arguments['query'] as String?)?.trim();
  final maxHeadings =
      ((arguments['max_headings'] as num?)?.toInt() ?? 60).clamp(10, 200);
  final hasSelector = (skillId?.isNotEmpty ?? false) ||
      (skillName?.isNotEmpty ?? false) ||
      (query?.isNotEmpty ?? false);

  final skill = _findSkill(
    source,
    skillId: skillId,
    skillName: skillName,
    query: query,
  );

  if (skill == null) {
    if (!hasSelector) {
      return jsonEncode({
        'success': true,
        'skills': source
            .map((s) => {
                  'id': s.id,
                  'name': s.name,
                  'description': s.description,
                  'enabled': s.enabled,
                })
            .toList(growable: false),
        'hint':
            'Specify skill_id or skill_name, then call load_skill_index again.',
      });
    }
    return jsonEncode({
      'error': 'Skill not found',
      'available_skills': source
          .map((s) => {
                'id': s.id,
                'name': s.name,
                'enabled': s.enabled,
              })
          .toList(growable: false),
    });
  }

  final headings = _extractHeadings(skill.body, maxHeadings: maxHeadings);
  return jsonEncode({
    'success': true,
    'skill': {
      'id': skill.id,
      'name': skill.name,
      'description': skill.description,
      'allowed_tools': skill.allowedTools,
      'enabled': skill.enabled,
      'path': skill.path,
    },
    'index': {
      'body_chars': skill.body.length,
      'body_lines': _countLines(skill.body),
      'heading_count': headings.length,
      'headings': headings,
    },
    'hint':
        'Then call load_skill with skill_id and section/query, or use start_line/end_line for precise range reads.',
  });
}

String _handleLoadSkillTool({
  required Map<String, dynamic> arguments,
  required List<SkillDefinition> skills,
}) {
  final source = _skillSource(skills);
  if (source.isEmpty) {
    return jsonEncode({'error': 'No skills available'});
  }

  final skillId = (arguments['skill_id'] as String?)?.trim();
  final skillName = (arguments['skill_name'] as String?)?.trim();
  final query = (arguments['query'] as String?)?.trim();
  final section = (arguments['section'] as String?)?.trim();
  final startLine = (arguments['start_line'] as num?)?.toInt();
  final endLine = (arguments['end_line'] as num?)?.toInt();
  final maxChars =
      ((arguments['max_chars'] as num?)?.toInt() ?? 3500).clamp(800, 8000);

  final skill = _findSkill(
    source,
    skillId: skillId,
    skillName: skillName,
    query: query,
  );
  if (skill == null) {
    return jsonEncode({
      'error': 'Skill not found',
      'available_skills': source
          .map((s) => {
                'id': s.id,
                'name': s.name,
                'enabled': s.enabled,
              })
          .toList(growable: false),
    });
  }

  final snippet = _extractSkillSnippet(
    skill: skill,
    section: section,
    query: query,
    startLine: startLine,
    endLine: endLine,
    maxChars: maxChars,
  );
  final body = snippet.content;
  final truncated = snippet.truncated;

  return jsonEncode({
    'success': true,
    'skill': {
      'id': skill.id,
      'name': skill.name,
      'description': skill.description,
      'allowed_tools': skill.allowedTools,
      'enabled': skill.enabled,
      'path': skill.path,
    },
    'selection': {
      'mode': snippet.mode,
      'section': section ?? '',
      'query': query ?? '',
      'start_line': snippet.startLine,
      'end_line': snippet.endLine,
      'total_lines': snippet.totalLines,
      'max_chars': maxChars,
    },
    'content': body,
    'truncated': truncated,
    'hint':
        'Need another part? Call load_skill again with section/query or start_line/end_line.',
  });
}

Future<String> _handleLoadSkillFileTool({
  required Map<String, dynamic> arguments,
  required List<SkillDefinition> skills,
}) async {
  final source = _skillSource(skills);
  if (source.isEmpty) {
    return jsonEncode({'error': 'No skills available'});
  }

  final skillId = (arguments['skill_id'] as String?)?.trim();
  final skillName = (arguments['skill_name'] as String?)?.trim();
  final skillQuery = (arguments['query'] as String?)?.trim();
  final section = (arguments['section'] as String?)?.trim();
  final maxChars =
      ((arguments['max_chars'] as num?)?.toInt() ?? 3500).clamp(800, 12000);
  final filePath =
      ((arguments['file_path'] ?? arguments['path']) as String?)?.trim() ?? '';

  final skill = _findSkill(
    source,
    skillId: skillId,
    skillName: skillName,
    query: skillQuery,
  );
  if (skill == null) {
    return jsonEncode({
      'error': 'Skill not found',
      'available_skills': source
          .map((s) => {
                'id': s.id,
                'name': s.name,
                'enabled': s.enabled,
              })
          .toList(growable: false),
    });
  }

  final skillDir = File(skill.path).parent;
  final files = await _listSkillFiles(skillDir);
  if (filePath.isEmpty) {
    return jsonEncode({
      'success': true,
      'skill': {
        'id': skill.id,
        'name': skill.name,
        'description': skill.description,
        'allowed_tools': skill.allowedTools,
        'enabled': skill.enabled,
        'path': skill.path,
      },
      'files': files,
      'hint':
          'Set file_path (ex: HEARTBEAT.md or references/api.md), then call load_skill_file again.',
    });
  }

  final resolved = _resolveSkillFile(
    skillDir: skillDir,
    requestedPath: filePath,
  );
  if (resolved.$1 != null) {
    return jsonEncode({
      'error': resolved.$1,
      'available_files': files,
    });
  }

  final file = resolved.$2!;
  if (!await file.exists()) {
    return jsonEncode({
      'error': 'File not found: $filePath',
      'available_files': files,
    });
  }

  final raw = await file.readAsString();
  var selected = raw;
  if (section != null && section.trim().isNotEmpty) {
    final bySection =
        _extractSectionByHeading(raw, section.trim().toLowerCase());
    if (bySection.trim().isNotEmpty) {
      selected = bySection.trim();
    }
  }

  final truncated = selected.length > maxChars;
  final content =
      truncated ? '${selected.substring(0, maxChars)}\n...' : selected;
  final headings = _extractHeadings(raw, maxHeadings: 80);

  return jsonEncode({
    'success': true,
    'skill': {
      'id': skill.id,
      'name': skill.name,
      'description': skill.description,
      'allowed_tools': skill.allowedTools,
      'enabled': skill.enabled,
      'path': skill.path,
    },
    'file': {
      'requested': filePath,
      'resolved': resolved.$3,
      'chars': raw.length,
      'lines': _countLines(raw),
      'heading_count': headings.length,
      'headings': headings,
    },
    'selection': {
      'section': section ?? '',
      'max_chars': maxChars,
    },
    'content': content,
    'truncated': truncated,
    'hint': 'Need another file? Call load_skill_file with file_path.',
  });
}
