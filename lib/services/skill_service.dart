import 'dart:io';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/skill_definition.dart';

class SkillService {
  static const String _enabledSkillsKey = 'enabled_skill_ids_v1';
  static const String _seededDefaultSkillKey = 'seeded_default_skill_v1';
  static const String _weatherSkillId = 'weather-check';
  static const String _weatherSkillName = 'Weather Check';
  static const String _weatherSkillDescription = 'Googleで指定地域の天気を確認する';
  static const List<String> _weatherAllowedTools = <String>[
    'navigate_to',
    'get_page_content',
    'extract_structured',
  ];
  static const String _weatherSkillBody = '''
Goal:
- 指定した地域の天気を確認する。

When to use:
- ユーザーが「天気」「気温」「予報」を知りたい時。

Steps:
1. `navigate_to` で `https://www.google.com/search?q=<地域>+天気` に移動する。
2. `extract_structured` で現在気温・概要・最高/最低を抽出する。
3. 抽出が難しい場合は `get_page_content` でページ内容を取得して要点を返す。
''';
  static const String _moltbookSkillId = 'moltbook-post';
  static const String _moltbookSkillName = 'Moltbook Post';
  static const String _moltbookSkillDescription =
      'Moltbook API で投稿/verify/掲示板取得を行う';
  static const List<String> _moltbookAllowedTools = <String>['http_request'];
  static const String _moltbookSkillBody = '''
Goal:
- Moltbook API を `http_request` で操作し、掲示板確認と投稿/verifyを行う。

Prerequisite:
- 設定 > Tool API Profiles で Moltbook APIキーを登録する。
- 例: profile id `test-molt-key`

Rules:
- `https://www.moltbook.com/api/v1` だけを使う（wwwなしは禁止）。
- APIキーは本文に書かない。`auth_profile` を毎回指定する。

Examples:
1. 掲示板一覧
```json
{
  "url": "https://www.moltbook.com/api/v1/submolts",
  "method": "GET",
  "auth_profile": "test-molt-key"
}
```

2. 新着投稿
```json
{
  "url": "https://www.moltbook.com/api/v1/posts?sort=new&limit=10",
  "method": "GET",
  "auth_profile": "test-molt-key"
}
```

3. 投稿
```json
{
  "url": "https://www.moltbook.com/api/v1/posts",
  "method": "POST",
  "auth_profile": "test-molt-key",
  "body": {
    "submolt_name": "general",
    "title": "Hello",
    "content": "Posted from HakoBrowseAI"
  }
}
```

4. Verify
```json
{
  "url": "https://www.moltbook.com/api/v1/verify",
  "method": "POST",
  "auth_profile": "test-molt-key",
  "body": {
    "verification_code": "<verification_code>",
    "answer": "<answer>"
  }
}
```
''';

  SkillDefinition buildDefaultSkillDefinition({
    bool enabled = true,
    String? path,
  }) {
    return SkillDefinition(
      id: _weatherSkillId,
      name: _weatherSkillName,
      description: _weatherSkillDescription,
      allowedTools: _weatherAllowedTools,
      body: _weatherSkillBody.trim(),
      path: path ?? 'private/skills/$_weatherSkillId/SKILL.md',
      enabled: enabled,
    );
  }

  SkillDefinition buildDefaultMoltbookSkillDefinition({
    bool enabled = true,
    String? path,
  }) {
    return SkillDefinition(
      id: _moltbookSkillId,
      name: _moltbookSkillName,
      description: _moltbookSkillDescription,
      allowedTools: _moltbookAllowedTools,
      body: _moltbookSkillBody.trim(),
      path: path ?? 'private/skills/$_moltbookSkillId/SKILL.md',
      enabled: enabled,
    );
  }

  List<SkillDefinition> buildBundledDefaultSkillDefinitions({
    bool weatherEnabled = true,
    bool moltbookEnabled = false,
    String pathRoot = 'private/skills',
  }) {
    return <SkillDefinition>[
      buildDefaultSkillDefinition(
        enabled: weatherEnabled,
        path: '$pathRoot/$_weatherSkillId/SKILL.md',
      ),
      buildDefaultMoltbookSkillDefinition(
        enabled: moltbookEnabled,
        path: '$pathRoot/$_moltbookSkillId/SKILL.md',
      ),
    ];
  }

  Future<List<SkillDefinition>> loadSkills({
    bool usePersistedEnabledIds = true,
    bool seedDefaultSkillIfNeeded = true,
  }) async {
    final enabled =
        usePersistedEnabledIds ? await _loadEnabledSkillIds() : <String>{};
    final skillsRoot = Directory('private/skills');
    if (seedDefaultSkillIfNeeded) {
      await _seedDefaultSkillIfNeeded(skillsRoot, enabled);
    } else if (!await skillsRoot.exists()) {
      await skillsRoot.create(recursive: true);
    }

    final out = <SkillDefinition>[];
    final dirs = await skillsRoot
        .list()
        .where((entity) => entity is Directory)
        .cast<Directory>()
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final dir in dirs) {
      final skill = await _loadSkillDir(dir, enabled);
      if (skill != null) out.add(skill);
    }
    return out;
  }

  Future<void> _seedDefaultSkillIfNeeded(
    Directory skillsRoot,
    Set<String> enabledIds,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final alreadySeeded = prefs.getBool(_seededDefaultSkillKey) ?? false;
    if (alreadySeeded) return;

    if (!await skillsRoot.exists()) {
      await skillsRoot.create(recursive: true);
    }
    final existing = await skillsRoot
        .list()
        .where((entity) => entity is Directory)
        .take(1)
        .toList();
    if (existing.isNotEmpty) {
      await prefs.setBool(_seededDefaultSkillKey, true);
      return;
    }

    final defaults = buildBundledDefaultSkillDefinitions(
      weatherEnabled: true,
      moltbookEnabled: false,
      pathRoot: skillsRoot.path,
    );
    for (final skill in defaults) {
      final skillDir = Directory('${skillsRoot.path}/${skill.id}');
      await skillDir.create(recursive: true);
      final content = _buildSkillMarkdown(
        name: skill.name,
        description: skill.description,
        allowedTools: skill.allowedTools,
        body: skill.body,
      );
      await File('${skillDir.path}/SKILL.md').writeAsString(content);
      enabledIds.add(skill.id);
    }
    await saveEnabledSkillIds(enabledIds);
    await prefs.setBool(_seededDefaultSkillKey, true);
  }

  Future<void> saveEnabledSkillIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_enabledSkillsKey, ids.toList()..sort());
  }

  Future<Set<String>> _loadEnabledSkillIds() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_enabledSkillsKey) ?? <String>[];
    return ids.toSet();
  }

  Future<SkillDefinition?> _loadSkillDir(
    Directory dir,
    Set<String> enabledIds,
  ) async {
    final file = File('${dir.path}/SKILL.md');
    if (!await file.exists()) return null;

    final content = await file.readAsString();
    final parsed = _parseSkill(content);
    final id = _basename(dir.path);
    return SkillDefinition(
      id: id,
      name: (parsed.frontmatter['name']?.toString().trim().isNotEmpty ?? false)
          ? parsed.frontmatter['name'].toString().trim()
          : id,
      description: parsed.frontmatter['description']?.toString().trim() ?? '',
      allowedTools: _parseAllowedTools(parsed.frontmatter['allowedTools']),
      body: parsed.body,
      path: file.path,
      enabled: enabledIds.contains(id),
    );
  }

  Future<void> saveSkill({
    String? existingId,
    required String name,
    required String description,
    required List<String> allowedTools,
    required String body,
    required bool enabled,
  }) async {
    final skillsRoot = Directory('private/skills');
    if (!await skillsRoot.exists()) {
      await skillsRoot.create(recursive: true);
    }

    final normalizedName = name.trim();
    final normalizedDesc = description.trim();
    final normalizedBody = body.trim();
    final id = existingId ?? await _nextAvailableId(skillsRoot, normalizedName);
    final skillDir = Directory('${skillsRoot.path}/$id');
    if (!await skillDir.exists()) {
      await skillDir.create(recursive: true);
    }

    final sortedTools = allowedTools.toSet().toList()..sort();
    final content = _buildSkillMarkdown(
      name: normalizedName,
      description: normalizedDesc,
      allowedTools: sortedTools,
      body: normalizedBody,
    );
    final file = File('${skillDir.path}/SKILL.md');
    await file.writeAsString(content);

    final enabledIds = await _loadEnabledSkillIds();
    if (enabled) {
      enabledIds.add(id);
    } else {
      enabledIds.remove(id);
    }
    await saveEnabledSkillIds(enabledIds);
  }

  Future<void> deleteSkill(String id) async {
    final dir = Directory('private/skills/$id');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    final enabledIds = await _loadEnabledSkillIds();
    if (enabledIds.remove(id)) {
      await saveEnabledSkillIds(enabledIds);
    }
  }

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

  Future<String> _nextAvailableId(Directory skillsRoot, String name) async {
    final base = _slugify(name);
    if (base.isEmpty) {
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
    var candidate = base;
    var suffix = 2;
    while (await Directory('${skillsRoot.path}/$candidate').exists()) {
      candidate = '$base-$suffix';
      suffix += 1;
    }
    return candidate;
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
}

class _ParsedSkill {
  final Map<String, dynamic> frontmatter;
  final String body;

  const _ParsedSkill({
    required this.frontmatter,
    required this.body,
  });
}
