part of 'skill_service.dart';

Future<void> _seedDefaultSkillIfNeeded({
  required SkillService service,
  required Directory skillsRoot,
  required Set<String> enabledIds,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final alreadySeeded =
      prefs.getBool(SkillService._seededDefaultSkillKey) ?? false;
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
    await prefs.setBool(SkillService._seededDefaultSkillKey, true);
    return;
  }

  final defaults = _buildBundledDefaultSkillDefinitions(
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
  await service.saveEnabledSkillIds(enabledIds);
  await prefs.setBool(SkillService._seededDefaultSkillKey, true);
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
