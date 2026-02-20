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
