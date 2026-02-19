// ignore_for_file: invalid_use_of_protected_member

part of '../main.dart';

extension _HomeStateBootstrapExt on _HomePageState {
  Future<void> _initializeApp() async {
    _syncAllAgentContexts();
    await _loadConfig();
    await _loadAgentProfiles();
    await _loadSkills();
    await _loadBookmarks();
    await _initTabs();
    await _restoreSession();
  }

  Future<void> _loadConfig() async {
    final loaded = await _settingsService.load();
    _log(
      'Loaded config: provider=${_settingsService.providerId(loaded.provider)}, auth=${_settingsService.authMethodId(loaded.authMethod)}, api_key=${loaded.apiKey.trim().isEmpty ? "unset" : "set"}',
    );
    _applySettings(loaded);
  }

  Future<void> _loadAgentProfiles() async {
    final profiles = await _agentProfileService.loadProfiles();
    if (!mounted) return;
    final profileIds = profiles.map((p) => p.id).toSet();
    final retained = _selectedAgentIds.where(profileIds.contains).toSet();
    final selectedId = retained.isNotEmpty
        ? retained.first
        : (profiles.isNotEmpty ? profiles.first.id : null);
    setState(() {
      _agentProfiles = profiles;
      _selectedAgentIds = selectedId == null ? <String>{} : {selectedId};
    });
    for (final p in profiles) {
      _contextForAgent(p.id);
    }
    _syncAllAgentContexts();
    _log('Loaded agent profiles: ${profiles.map((p) => p.name).join(', ')}');
    _markSessionDirty();
  }

  Future<void> _loadSkills() async {
    try {
      final skills = await _skillService
          .loadSkills()
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
    _markSessionDirty();
  }

  Future<void> _persistEnabledSkills(List<SkillDefinition> skills) async {
    try {
      final enabledIds =
          skills.where((s) => s.enabled).map((s) => s.id).toSet();
      await _skillService.saveEnabledSkillIds(enabledIds);
    } catch (e) {
      _log('Save enabled skills failed: $e');
    }
  }

  Future<void> _showCreateSkillDialog() async {
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
    _markSessionDirty();
  }

  Future<void> _showEditSkillDialog(SkillDefinition skill) async {
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
    _markSessionDirty();
  }

  Future<void> _deleteSkillWithConfirm(SkillDefinition skill) async {
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
    _markSessionDirty();
  }

  Future<_SkillEditorDraft?> _showSkillEditorDialog({
    SkillDefinition? initial,
  }) async {
    final nameController = TextEditingController(text: initial?.name ?? '');
    final descriptionController =
        TextEditingController(text: initial?.description ?? '');
    final bodyController = TextEditingController(
      text: initial?.body ?? _defaultSkillBodyTemplate(),
    );
    var enabled = initial?.enabled ?? true;
    var allowAllTools = initial == null ? true : initial.allowedTools.isEmpty;
    final selectedTools = {...initial?.allowedTools ?? const <String>[]};
    final toolNames = ToolRegistry.definitions.map((d) => d.name).toList()
      ..sort();
    String? validationError;

    final result = await showDialog<_SkillEditorDraft>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(initial == null ? 'New Skill' : 'Edit Skill'),
          content: SizedBox(
            width: 660,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (initial != null) ...[
                    Text(
                      'Skill ID: ${initial.id}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descriptionController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: enabled,
                    title: const Text('Enabled'),
                    onChanged: (v) => setLocalState(() => enabled = v),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: allowAllTools,
                    title: const Text('Allow all tools'),
                    subtitle: const Text('OFF の場合だけ個別にチェック'),
                    onChanged: (v) => setLocalState(() => allowAllTools = v),
                  ),
                  if (!allowAllTools)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: toolNames
                            .map(
                              (tool) => FilterChip(
                                label: Text(tool),
                                selected: selectedTools.contains(tool),
                                onSelected: (selected) {
                                  setLocalState(() {
                                    if (selected) {
                                      selectedTools.add(tool);
                                    } else {
                                      selectedTools.remove(tool);
                                    }
                                  });
                                },
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: bodyController,
                    maxLines: 14,
                    decoration: const InputDecoration(
                      labelText: 'SKILL body',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (validationError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      validationError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final desc = descriptionController.text.trim();
                final body = bodyController.text.trim();
                if (name.isEmpty) {
                  setLocalState(() {
                    validationError = 'Name is required.';
                  });
                  return;
                }
                if (!allowAllTools && selectedTools.isEmpty) {
                  setLocalState(() {
                    validationError =
                        'Select at least one tool or enable "Allow all tools".';
                  });
                  return;
                }
                Navigator.pop(
                  context,
                  _SkillEditorDraft(
                    name: name,
                    description: desc,
                    body: body,
                    enabled: enabled,
                    allowAllTools: allowAllTools,
                    allowedTools: selectedTools.toList()..sort(),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    descriptionController.dispose();
    bodyController.dispose();
    return result;
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

  Set<String>? _activeAllowedTools() {
    final enabled = _skills.where((s) => s.enabled).toList();
    if (enabled.isEmpty) return null;
    final out = <String>{};
    for (final s in enabled) {
      if (s.allowedTools.isEmpty) {
        return null;
      }
      out.addAll(s.allowedTools);
    }
    return out.isEmpty ? null : out;
  }

  String _buildSkillAwareSystemPrompt({
    required AgentProfile profile,
    required String userMessage,
  }) {
    final basePrompt = profile.buildSystemPrompt();
    final enabled = _skills.where((s) => s.enabled).toList();
    if (enabled.isEmpty) return basePrompt;

    final summaryLines = enabled.map((skill) {
      final tools =
          skill.allowedTools.isEmpty ? 'ALL' : skill.allowedTools.join(', ');
      final desc = skill.description.trim().isEmpty
          ? '(no description)'
          : skill.description.trim();
      return '- ${skill.name}: $desc | allowedTools: $tools';
    }).join('\n');

    final relevant = _pickRelevantSkills(userMessage, enabled);
    final detailBlocks = relevant
        .map((skill) {
          final body = skill.body.trim();
          if (body.isEmpty) return '';
          const maxChars = 2200;
          final clipped = body.length <= maxChars
              ? body
              : '${body.substring(0, maxChars)}\n...';
          return 'Skill: ${skill.name}\n$clipped';
        })
        .where((v) => v.isNotEmpty)
        .join('\n\n');

    final sections = <String>[
      basePrompt,
      '''
SKILLS (enabled)
$summaryLines

Use skills only when relevant to the current user request.
Respect allowedTools for each skill.
''',
    ];
    if (detailBlocks.isNotEmpty) {
      sections.add('''
SKILL DETAILS (relevant only)
$detailBlocks
''');
    }
    return sections.where((s) => s.trim().isNotEmpty).join('\n\n');
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

  void _selectAgent(String agentId) {
    if (_agentProfiles.isEmpty) return;
    setState(() {
      _selectedAgentIds = {agentId};
    });
    _markSessionDirty();
  }

  Future<void> _showEditAgentDialog() async {
    final profile = _activeAgentProfile;
    if (profile == null) return;
    final nameController = TextEditingController(text: profile.name);
    final soulController = TextEditingController(text: profile.soul);
    final userController = TextEditingController(text: profile.userProfile);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Agent: ${profile.name}'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Name',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  maxLines: 1,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Display name shown in UI',
                  ),
                ),
                const SizedBox(height: 12),
                const Text('SOUL.md',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: soulController,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Core principles / boundaries / style',
                  ),
                ),
                const SizedBox(height: 12),
                const Text('USER.md',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: userController,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'User preferences / profile',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true) {
      nameController.dispose();
      soulController.dispose();
      userController.dispose();
      return;
    }

    final name = nameController.text.trim();
    final soul = soulController.text;
    final user = userController.text;
    nameController.dispose();
    soulController.dispose();
    userController.dispose();

    await _agentProfileService.saveProfile(
      profile: profile,
      name: name.isEmpty ? profile.name : name,
      soul: soul,
      userProfile: user,
    );
    await _loadAgentProfiles();
    final updatedName = name.isEmpty ? profile.name : name;
    _log('Agent profile updated: $updatedName');
    if (!mounted) return;
    setState(() {
      _messages.add(
        ChatMessage(
          text: 'Updated agent profile: $updatedName',
          isUser: false,
        ),
      );
      _enforceChatMessageLimit();
    });
    _markSessionDirty();
  }

  Future<void> _loadBookmarks() async {
    final bookmarks = await _bookmarkService.loadBookmarks();
    if (!mounted) return;
    setState(() {
      _bookmarks = bookmarks;
    });
    _log('Loaded bookmarks: ${_bookmarkService.countLinks(bookmarks)} links');
  }

  void _applySettings(AppSettings settings) {
    setState(() {
      _settings = settings;
      _maxContentLength = settings.maxContentLength;
      _chatMaxMessages = settings.chatMaxMessages;
      _leftPanelWidth = settings.leftPanelWidth;
      _syncAllAgentContexts();
      _enforceChatMessageLimit();

      if (settings.authMethod == AuthMethod.apiKey &&
          settings.apiKey.trim().isNotEmpty) {
        _config = AiServiceConfig(
          provider: settings.provider,
          apiKey: settings.apiKey,
          baseUrl: settings.baseUrl,
          model: settings.model,
        );
        _aiService = AiService(config: _config!);
      } else {
        _config = null;
        _aiService = null;
      }
      _isLoading = false;
    });
    if (_leftTabIndex == 0) {
      _ensureChatBottomAfterViewSwitch();
    }
    _markSessionDirty();
  }

  Future<void> _showSettingsDialog() async {
    final next = await showSettingsDialog(
      context,
      initial: _settings,
      settingsService: _settingsService,
      log: _log,
    );
    if (next == null) return;

    await _settingsService.save(next);
    _log(
      'Saved config: provider=${_settingsService.providerId(next.provider)}, auth=${_settingsService.authMethodId(next.authMethod)}, chat_max_messages=${next.chatMaxMessages}',
    );
    _applySettings(next);
  }
}

class _SkillEditorDraft {
  final String name;
  final String description;
  final String body;
  final bool enabled;
  final bool allowAllTools;
  final List<String> allowedTools;

  const _SkillEditorDraft({
    required this.name,
    required this.description,
    required this.body,
    required this.enabled,
    required this.allowAllTools,
    required this.allowedTools,
  });
}
