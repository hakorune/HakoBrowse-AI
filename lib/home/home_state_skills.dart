// ignore_for_file: invalid_use_of_protected_member

part of '../main.dart';

extension _HomeStateSkillsExt on _HomePageState {
  Future<void> _loadSkills() async {
    if (_defaultStateMode) {
      final skills = _skillService.buildBundledDefaultSkillDefinitions(
        weatherEnabled: true,
        moltbookEnabled: false,
        pathRoot: '(default-state)',
      );
      if (!mounted) return;
      setState(() {
        _skills = skills;
      });
      _log('Loaded skills: ${skills.length} (default-state mode)');
      return;
    }
    try {
      final skills = await _skillService
          .loadSkills(
            usePersistedEnabledIds: true,
            seedDefaultSkillIfNeeded: true,
          )
          .timeout(const Duration(seconds: 6), onTimeout: () => _skills);
      if (!mounted) return;
      setState(() {
        _skills = skills;
      });
      _log('Loaded skills: ${skills.length}');
    } catch (e) {
      _log('Load skills failed: $e');
      if (!mounted) return;
      setState(() {
        _skills = <SkillDefinition>[];
      });
    }
  }

  Future<void> _toggleSkill(String skillId, bool enabled) async {
    final next = _skills
        .map((s) => s.id == skillId ? s.copyWith(enabled: enabled) : s)
        .toList();
    setState(() {
      _skills = next;
    });
    unawaited(_persistEnabledSkills(next));
    _markSessionDirty(reason: 'toggle_skill', saveSoon: true);
  }

  Future<void> _persistEnabledSkills(List<SkillDefinition> skills) async {
    if (_defaultStateMode) return;
    try {
      final enabledIds =
          skills.where((s) => s.enabled).map((s) => s.id).toSet();
      await _skillService.saveEnabledSkillIds(enabledIds);
    } catch (e) {
      _log('Save enabled skills failed: $e');
    }
  }

  Future<void> _showCreateSkillDialog() async {
    if (_defaultStateMode) {
      _log('Skill create skipped: default-state mode');
      return;
    }
    if (_isSkillEditorOpen) return;
    final draft = await _showSkillEditorDialog();
    if (draft == null) return;
    await _skillService.saveSkill(
      name: draft.name,
      description: draft.description,
      allowedTools: draft.allowAllTools ? const <String>[] : draft.allowedTools,
      body: draft.body,
      enabled: draft.enabled,
    );
    await _loadSkills();
    if (!mounted) return;
    setState(() {
      _messages.add(
        ChatMessage(text: 'Skill created: ${draft.name}', isUser: false),
      );
      _enforceChatMessageLimit();
    });
    _markSessionDirty(reason: 'create_skill', saveSoon: true);
  }

  Future<void> _showEditSkillDialog(SkillDefinition skill) async {
    if (_defaultStateMode) {
      _log('Skill edit skipped: default-state mode');
      return;
    }
    if (_isSkillEditorOpen) return;
    final draft = await _showSkillEditorDialog(initial: skill);
    if (draft == null) return;
    await _skillService.saveSkill(
      existingId: skill.id,
      name: draft.name,
      description: draft.description,
      allowedTools: draft.allowAllTools ? const <String>[] : draft.allowedTools,
      body: draft.body,
      enabled: draft.enabled,
    );
    await _loadSkills();
    _log('Skill updated: ${skill.id}');
    _markSessionDirty(reason: 'edit_skill', saveSoon: true);
  }

  Future<void> _deleteSkillWithConfirm(SkillDefinition skill) async {
    if (_defaultStateMode) {
      _log('Skill delete skipped: default-state mode');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete skill'),
        content: Text('Delete skill "${skill.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _skillService.deleteSkill(skill.id);
    await _loadSkills();
    _log('Skill deleted: ${skill.id}');
    _markSessionDirty(reason: 'delete_skill', saveSoon: true);
  }

  Future<void> _showToolAuthProfilesManager() async {
    if (_defaultStateMode) {
      _log('Tool auth profile edit skipped: default-state mode');
      return;
    }
    final updated = await showToolAuthProfilesDialog(
      context: context,
      service: _toolAuthProfileService,
      initial: _toolAuthProfiles,
    );
    if (updated == null) return;
    await _toolAuthProfileService.saveProfiles(updated);
    await _loadToolAuthProfiles();
    _markSessionDirty(reason: 'manage_tool_auth_profiles', saveSoon: true);
  }

  Future<_SkillEditorDraft?> _showSkillEditorDialog({
    SkillDefinition? initial,
  }) async {
    if (!mounted || _isSkillEditorOpen) return null;
    _isSkillEditorOpen = true;
    _debugLogUiRefreshDebounce?.cancel();
    _muteDebugUiUpdates(duration: const Duration(seconds: 2));
    _pauseSessionSave(
      duration: const Duration(seconds: 12),
      reason: 'skill_editor_open',
    );
    final initialBodyLength = initial?.body.length ?? 0;
    if (initialBodyLength > 20000) {
      _log('Opening large skill body in editor: $initialBodyLength chars');
    }

    final toolNames = ToolRegistry.definitions.map((d) => d.name).toList()
      ..sort();
    try {
      final result = await Navigator.of(context).push<_SkillEditorDraft>(
        MaterialPageRoute<_SkillEditorDraft>(
          fullscreenDialog: true,
          builder: (routeContext) => _SkillEditorScreen(
            initial: initial,
            toolNames: toolNames,
            defaultBodyTemplate: _defaultSkillBodyTemplate(),
          ),
        ),
      );
      if (result == null) {
        _log('Skill editor: cancel');
      } else {
        _log('Skill editor: save');
      }
      return result;
    } catch (e) {
      _log('Skill editor dialog failed: $e');
      return null;
    } finally {
      _isSkillEditorOpen = false;
      _debugLogUiRefreshDebounce?.cancel();
      _muteDebugUiUpdates(duration: const Duration(seconds: 1));
      _pauseSessionSave(
        duration: const Duration(seconds: 4),
        reason: 'skill_editor_close',
      );
      if (_sessionDirty) {
        _queueSessionSave(
          reason: 'skill_editor_close',
          delay: const Duration(seconds: 5),
        );
      }
    }
  }

  String _defaultSkillBodyTemplate() {
    return '''
Goal:
- Describe what this skill should accomplish.

When to use:
- Describe trigger conditions.

Steps:
1. Navigate / inspect page.
2. Extract what is needed.
3. Summarize and report result.
''';
  }

  Set<String>? _activeAllowedTools({String? userMessage}) {
    final enabled = _skills.where((s) => s.enabled).toList();
    if (enabled.isEmpty) return null;

    var scoped = enabled;
    final query = userMessage?.trim() ?? '';
    if (query.isNotEmpty) {
      final relevant = _pickRelevantSkills(query, enabled);
      if (relevant.isEmpty) {
        return null;
      }
      scoped = relevant;
    }

    final out = <String>{};
    for (final s in scoped) {
      if (s.allowedTools.isEmpty) {
        return null;
      }
      out.addAll(s.allowedTools);
    }
    out.add('load_skill_index');
    out.add('load_skill');
    out.add('load_skill_file');
    return out.isEmpty ? null : out;
  }

  String _buildSkillAwareSystemPrompt({
    required AgentProfile profile,
    required String userMessage,
  }) {
    final basePrompt = profile.buildSystemPrompt();
    final enabled = _skills.where((s) => s.enabled).toList();
    if (enabled.isEmpty) return basePrompt;

    const maxSkillSummaries = 24;
    final summaryList = enabled.take(maxSkillSummaries).map((skill) {
      final name = _clipPromptText(skill.name.trim(), max: 64);
      final tools =
          skill.allowedTools.isEmpty ? 'ALL' : skill.allowedTools.join(', ');
      final desc = skill.description.trim().isEmpty
          ? '(no description)'
          : _clipPromptText(skill.description.trim(), max: 140);
      return '- id=${skill.id}, name=$name, desc=$desc, allowedTools=$tools';
    }).toList(growable: true);
    if (enabled.length > maxSkillSummaries) {
      summaryList.add(
        '- ... ${enabled.length - maxSkillSummaries} more enabled skill(s) omitted from prompt metadata',
      );
    }
    final summaryLines = summaryList.join('\n');

    final relevant = _pickRelevantSkills(userMessage, enabled);
    final relevantLines = relevant
        .map(
          (skill) =>
              '- ${skill.name} (id=${skill.id}, allowedTools=${skill.allowedTools.isEmpty ? "ALL" : skill.allowedTools.join(", ")})',
        )
        .join('\n');

    final sections = <String>[
      basePrompt,
      '''
SKILLS (enabled)
$summaryLines

Skill bodies are NOT preloaded into this prompt.
When you need details, first call `load_skill_index` to inspect headings.
Then call `load_skill` with `skill_id` and `section`/`query`, or `start_line`/`end_line`, for only needed parts.
If needed, call `load_skill_file` to read additional files in the same skill folder (ex: HEARTBEAT.md / RULES.md).
Use `section`/`query` or line ranges to load only the needed part.
For authenticated API calls via `http_request`, specify `auth_profile` explicitly on each request.
Use skills only when relevant to the current user request.
Respect allowedTools for each skill and do not use disallowed tools.
''',
    ];
    if (relevantLines.isNotEmpty) {
      sections.add('''
RELEVANT SKILL HINTS (for this user request)
$relevantLines
''');
    }
    return sections.where((s) => s.trim().isNotEmpty).join('\n\n');
  }

  String _clipPromptText(String value, {required int max}) {
    final normalized = value.replaceAll('\n', ' ').replaceAll('\r', ' ').trim();
    if (normalized.length <= max) return normalized;
    return '${normalized.substring(0, max)}...';
  }

  List<SkillDefinition> _pickRelevantSkills(
    String message,
    List<SkillDefinition> enabled,
  ) {
    final query = message.toLowerCase().trim();
    if (query.isEmpty) return const <SkillDefinition>[];

    final scored = <({SkillDefinition skill, int score})>[];
    for (final skill in enabled) {
      final id = skill.id.toLowerCase();
      final name = skill.name.toLowerCase();
      final desc = skill.description.toLowerCase();
      final tokens = _keywordTokens('$name $desc');

      var score = 0;
      if (query.contains(id)) score += 4;
      if (query.contains(name)) score += 4;
      for (final token in tokens) {
        if (token.length < 3) continue;
        if (query.contains(token)) score += 1;
      }
      if (score > 0) {
        scored.add((skill: skill, score: score));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(2).map((x) => x.skill).toList(growable: false);
  }

  Set<String> _keywordTokens(String text) {
    return text
        .split(RegExp(r'[^a-z0-9]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet();
  }
}
