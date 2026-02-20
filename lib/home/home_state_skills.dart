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
