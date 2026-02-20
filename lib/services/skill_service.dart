import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/skill_definition.dart';

part 'skill_service_defaults.dart';
part 'skill_service_markdown.dart';
part 'skill_service_storage.dart';

class SkillService {
  static const String _enabledSkillsKey = 'enabled_skill_ids_v1';
  static const String _seededDefaultSkillKey = 'seeded_default_skill_v1';

  SkillDefinition buildDefaultSkillDefinition({
    bool enabled = true,
    String? path,
  }) {
    return _buildWeatherDefaultSkillDefinition(enabled: enabled, path: path);
  }

  SkillDefinition buildDefaultMoltbookSkillDefinition({
    bool enabled = true,
    String? path,
  }) {
    return _buildMoltbookDefaultSkillDefinition(enabled: enabled, path: path);
  }

  List<SkillDefinition> buildBundledDefaultSkillDefinitions({
    bool weatherEnabled = true,
    bool moltbookEnabled = false,
    String pathRoot = 'private/skills',
  }) {
    return _buildBundledDefaultSkillDefinitions(
      weatherEnabled: weatherEnabled,
      moltbookEnabled: moltbookEnabled,
      pathRoot: pathRoot,
    );
  }

  Future<List<SkillDefinition>> loadSkills({
    bool usePersistedEnabledIds = true,
    bool seedDefaultSkillIfNeeded = true,
  }) async {
    final enabled =
        usePersistedEnabledIds ? await _loadEnabledSkillIds() : <String>{};
    final skillsRoot = Directory('private/skills');
    if (seedDefaultSkillIfNeeded) {
      await _seedDefaultSkillIfNeeded(
        service: this,
        skillsRoot: skillsRoot,
        enabledIds: enabled,
      );
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

  Future<void> saveEnabledSkillIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_enabledSkillsKey, ids.toList()..sort());
  }

  Future<Set<String>> _loadEnabledSkillIds() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_enabledSkillsKey) ?? <String>[];
    return ids.toSet();
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
}
