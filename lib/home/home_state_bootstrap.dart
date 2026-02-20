// ignore_for_file: invalid_use_of_protected_member

part of '../main.dart';

extension _HomeStateBootstrapExt on _HomePageState {
  Future<void> _initializeApp() async {
    _syncAllAgentContexts();
    if (_defaultStateMode) {
      _log(
        'Launch mode: --default-state (ignoring persisted state; using preview defaults)',
      );
    }
    await _loadConfig();
    await _loadToolAuthProfiles();
    await _loadAgentProfiles();
    await _loadSkills();
    await _loadBookmarks();
    await _initTabs();
    if (_defaultStateMode) {
      _log('Session restore skipped by --default-state');
    } else {
      await _restoreSession();
    }
  }

  Future<void> _loadConfig() async {
    if (_defaultStateMode) {
      _applySettings(_settings);
      _log(
        'Loaded default config: provider=${_settingsService.providerId(_settings.provider)}, auth=${_settingsService.authMethodId(_settings.authMethod)}, api_key=unset',
      );
      return;
    }
    final loaded = await _settingsService.load();
    _log(
      'Loaded config: provider=${_settingsService.providerId(loaded.provider)}, auth=${_settingsService.authMethodId(loaded.authMethod)}, api_key=${loaded.apiKey.trim().isEmpty ? "unset" : "set"}',
    );
    _applySettings(loaded);
  }

  Future<void> _loadAgentProfiles() async {
    if (_defaultStateMode) {
      const profile = AgentProfile(
        id: 'default',
        name: 'default',
        directoryPath: '(default-state)',
        soul: '',
        userProfile: '',
      );
      if (!mounted) return;
      setState(() {
        _agentProfiles = const <AgentProfile>[profile];
        _selectedAgentIds = const <String>{'default'};
      });
      _contextForAgent(profile.id);
      _syncAllAgentContexts();
      _log('Loaded agent profiles: default (default-state mode)');
      return;
    }
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
    _markSessionDirty(reason: 'load_agent_profiles');
  }

  Future<void> _loadSkills() async {
    if (_defaultStateMode) {
      final skills = <SkillDefinition>[
        _skillService.buildDefaultSkillDefinition(
          enabled: true,
          path: '(default-state)',
        ),
      ];
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

  Future<void> _loadToolAuthProfiles() async {
    if (_defaultStateMode) {
      if (!mounted) return;
      setState(() {
        _toolAuthProfiles = <ToolAuthProfile>[];
      });
      _log('Loaded tool auth profiles: 0 (default-state mode)');
      return;
    }
    try {
      final profiles = await _toolAuthProfileService.loadProfiles();
      if (!mounted) return;
      setState(() {
        _toolAuthProfiles = profiles;
      });
      _log('Loaded tool auth profiles: ${profiles.length}');
    } catch (e) {
      _log('Load tool auth profiles failed: $e');
      if (!mounted) return;
      setState(() {
        _toolAuthProfiles = <ToolAuthProfile>[];
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

  void _selectAgent(String agentId) {
    if (_agentProfiles.isEmpty) return;
    setState(() {
      _selectedAgentIds = {agentId};
    });
    _markSessionDirty(reason: 'select_agent', saveSoon: true);
  }

  Future<void> _showEditAgentDialog() async {
    if (_defaultStateMode) {
      _log('Agent profile edit skipped: default-state mode');
      return;
    }
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
    _markSessionDirty(reason: 'apply_settings', saveSoon: true);
  }

  Future<void> _loadBookmarks() async {
    if (_defaultStateMode) {
      if (!mounted) return;
      setState(() {
        _bookmarks = <BookmarkNode>[];
      });
      _log('Loaded bookmarks: 0 links (default-state mode)');
      return;
    }
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
    _markSessionDirty(reason: 'edit_agent', saveSoon: true);
  }

  Future<void> _showSettingsDialog() async {
    final next = await showSettingsDialog(
      context,
      initial: _settings,
      settingsService: _settingsService,
      toolAuthProfileService: _toolAuthProfileService,
      log: _log,
      persistToolAuthProfiles: !_defaultStateMode,
    );
    if (next == null) return;

    if (_defaultStateMode) {
      _log(
        'Applied config (runtime only, not persisted): provider=${_settingsService.providerId(next.provider)}, auth=${_settingsService.authMethodId(next.authMethod)}, chat_max_messages=${next.chatMaxMessages}',
      );
    } else {
      await _loadToolAuthProfiles();
      await _settingsService.save(next);
      _log(
        'Saved config: provider=${_settingsService.providerId(next.provider)}, auth=${_settingsService.authMethodId(next.authMethod)}, chat_max_messages=${next.chatMaxMessages}',
      );
    }
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

class _SkillEditorScreen extends StatefulWidget {
  final SkillDefinition? initial;
  final List<String> toolNames;
  final String defaultBodyTemplate;

  const _SkillEditorScreen({
    required this.initial,
    required this.toolNames,
    required this.defaultBodyTemplate,
  });

  @override
  State<_SkillEditorScreen> createState() => _SkillEditorScreenState();
}

class _SkillEditorScreenState extends State<_SkillEditorScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _bodyController;
  late bool _enabled;
  late bool _allowAllTools;
  late final Set<String> _selectedTools;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial?.name ?? '');
    _descriptionController =
        TextEditingController(text: widget.initial?.description ?? '');
    _bodyController = TextEditingController(
      text: widget.initial?.body ?? widget.defaultBodyTemplate,
    );
    _enabled = widget.initial?.enabled ?? true;
    _allowAllTools =
        widget.initial == null ? true : widget.initial!.allowedTools.isEmpty;
    _selectedTools = {...widget.initial?.allowedTools ?? const <String>[]};
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _clearValidation() {
    if (_validationError == null) return;
    setState(() {
      _validationError = null;
    });
  }

  void _cancel() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();
  }

  void _save() {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final body = _bodyController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _validationError = 'Name is required.';
      });
      return;
    }
    if (!_allowAllTools && _selectedTools.isEmpty) {
      setState(() {
        _validationError =
            'Select at least one tool or enable "Allow all tools".';
      });
      return;
    }
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(
      _SkillEditorDraft(
        name: name,
        description: description,
        body: body,
        enabled: _enabled,
        allowAllTools: _allowAllTools,
        allowedTools: _selectedTools.toList()..sort(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.initial == null ? 'New Skill' : 'Edit Skill';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          onPressed: _cancel,
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.initial != null) ...[
                Text(
                  'Skill ID: ${widget.initial!.id}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: _nameController,
                autocorrect: false,
                enableSuggestions: false,
                spellCheckConfiguration:
                    const SpellCheckConfiguration.disabled(),
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                onChanged: (_) => _clearValidation(),
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLines: 2,
                autocorrect: false,
                enableSuggestions: false,
                spellCheckConfiguration:
                    const SpellCheckConfiguration.disabled(),
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                onChanged: (_) => _clearValidation(),
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _enabled,
                title: const Text('Enabled'),
                onChanged: (v) => setState(() => _enabled = v),
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _allowAllTools,
                title: const Text('Allow all tools'),
                subtitle: const Text('OFF の場合だけ個別にチェック'),
                onChanged: (v) => setState(() => _allowAllTools = v),
              ),
              if (!_allowAllTools)
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 120),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.toolNames
                          .map(
                            (tool) => FilterChip(
                              label: Text(tool),
                              selected: _selectedTools.contains(tool),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedTools.add(tool);
                                  } else {
                                    _selectedTools.remove(tool);
                                  }
                                });
                              },
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: TextField(
                  controller: _bodyController,
                  maxLines: null,
                  expands: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  spellCheckConfiguration:
                      const SpellCheckConfiguration.disabled(),
                  smartDashesType: SmartDashesType.disabled,
                  smartQuotesType: SmartQuotesType.disabled,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  onChanged: (_) => _clearValidation(),
                  decoration: const InputDecoration(
                    labelText: 'SKILL body',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              if (_validationError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _validationError!,
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
    );
  }
}
