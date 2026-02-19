// ignore_for_file: invalid_use_of_protected_member

part of '../main.dart';

const List<String> _slashCommands = <String>[
  '/compress',
  '/clear',
  '/reload_agent',
  '/reload_skill',
];

extension _HomeStateChatExt on _HomePageState {
  void _cancelAiResponse() {
    if (!_isAiResponding) return;
    _activeCancelToken?.cancel();
    _log('Cancel requested by user');
  }

  void _clearChatViewOnly() {
    if (_isAiResponding) return;
    if (_messages.isEmpty) return;
    setState(() {
      _messages.clear();
    });
    _markSessionDirty();
    _log('Chat view cleared (context preserved)');
  }

  Future<String> _executeToolForAgent(
    String agentId,
    String toolName,
    Map<String, dynamic> arguments,
  ) async {
    final trace = _startToolTrace(
      agentId: agentId,
      toolName: toolName,
      arguments: arguments,
    );
    final stopwatch = Stopwatch()..start();
    try {
      _log('Tool called: $toolName, args: $arguments');
      _contextForAgent(agentId).setLastTool(toolName);
      final result = await ToolExecutorService.execute(
        context: context,
        toolName: toolName,
        arguments: arguments,
        activeController: _activeController,
        useHtmlContent: _useHtmlContent,
        maxContentLength: _maxContentLength,
        currentUrl: _currentUrl,
        enableSafetyGate: _enableSafetyGate,
        bookmarks: _bookmarks,
        bookmarkService: _bookmarkService,
        onBookmarksChanged: (updated) async {
          if (!mounted) return;
          setState(() {
            _bookmarks = updated;
          });
        },
        onNavigated: (url) {
          _contextForAgent(agentId).updateCurrentUrl(url);
          _syncAllAgentContexts();
        },
        onCreateTab: _createTab,
        log: _log,
        shorten: _shorten,
      );
      stopwatch.stop();
      final success = !result.toLowerCase().contains('"error"');
      _finishToolTrace(
        traceId: trace.id,
        durationMs: stopwatch.elapsedMilliseconds,
        success: success,
        resultPreview: result,
      );
      return result;
    } catch (e) {
      stopwatch.stop();
      _finishToolTrace(
        traceId: trace.id,
        durationMs: stopwatch.elapsedMilliseconds,
        success: false,
        errorMessage: e.toString(),
      );
      return jsonEncode({'error': 'Tool execution failed: $e'});
    }
  }

  Future<void> _sendMessage() async {
    if (_inputController.text.trim().isEmpty || _isAiResponding) return;
    final userMessage = _inputController.text.trim();
    _inputController.clear();

    final handled = await _handleSlashCommand(userMessage);
    if (handled) return;

    if (_aiService == null) {
      _log('Error: AiService is null');
      final message = _settings.authMethod == AuthMethod.oauth
          ? (_settings.oauthToken.isNotEmpty
              ? 'OAuth token was saved, but API login handoff is not implemented yet. Please use API Key for now.'
              : 'OAuth is selected. Open Settings -> Start Browser Auth, then paste token/code. API handoff is still experimental.')
          : 'AI is not configured. Please open Settings and set API key.';
      setState(() {
        _messages.add(ChatMessage(text: message, isUser: false));
        _enforceChatMessageLimit();
      });
      _scrollChatToBottom();
      return;
    }
    if (_agentProfiles.isEmpty || _selectedAgentIds.isEmpty) {
      setState(() {
        _messages.add(
          ChatMessage(
            text:
                'No agent profile selected. Add SOUL.md/USER.md in private/agent or private/agents/<name>.',
            isUser: false,
          ),
        );
        _enforceChatMessageLimit();
      });
      _scrollChatToBottom();
      return;
    }

    _log('User: $userMessage');

    setState(() {
      _messages.add(ChatMessage(text: userMessage, isUser: true));
      _enforceChatMessageLimit();
      _isAiResponding = true;
    });
    final cancelToken = AiCancelToken();
    _activeCancelToken = cancelToken;
    _scrollChatToBottom(animated: false);
    _markSessionDirty();

    final activeProfiles =
        _agentProfiles.where((p) => _selectedAgentIds.contains(p.id)).toList();
    final allowedTools = _activeAllowedTools(userMessage: userMessage);
    for (final profile in activeProfiles) {
      _contextForAgent(profile.id).addUserText(userMessage);
    }

    try {
      await Future.wait(
        activeProfiles.map((profile) {
          return _chatFlow.processAiResponse(
            aiService: _aiService!,
            messages: _messages,
            executeTool: (tool, args) =>
                _executeToolForAgent(profile.id, tool, args),
            setState: setState,
            log: (message) => _log('[${profile.name}] $message'),
            contextManager: _contextForAgent(profile.id),
            systemPrompt: _buildSkillAwareSystemPrompt(
              profile: profile,
              userMessage: userMessage,
            ),
            allowedToolNames: allowedTools,
            assistantLabel: profile.name,
            cancelToken: cancelToken,
            setAiResponding: (_) {},
            manageRespondingFlag: false,
          );
        }),
      );
    } finally {
      _activeCancelToken = null;
      if (mounted) {
        setState(() {
          _enforceChatMessageLimit();
          _isAiResponding = false;
        });
        _scrollChatToBottom();
        _markSessionDirty();
      }
    }
  }

  Future<bool> _handleSlashCommand(String input) async {
    final command = input.trim().toLowerCase();
    if (!command.startsWith('/')) return false;

    if (command == '/clear') {
      await _clearConversation();
      setState(() {
        _messages
            .add(ChatMessage(text: 'Conversation cleared.', isUser: false));
        _enforceChatMessageLimit();
      });
      _scrollChatToBottom();
      _markSessionDirty();
      _log('Command: /clear');
      return true;
    }

    if (command == '/compress') {
      var compactedCount = 0;
      var maxTokens = 0;
      for (final entry in _agentContexts.entries) {
        final compacted = entry.value.compactNow();
        if (compacted) compactedCount++;
        final context = entry.value.buildMessages();
        maxTokens = math.max(maxTokens, context.estimatedTokens);
      }
      final text = compactedCount > 0
          ? 'Context compressed for $compactedCount agent(s). Max estimated tokens: $maxTokens'
          : 'Not enough history to compress yet.';
      setState(() {
        _messages.add(ChatMessage(text: text, isUser: false));
        _enforceChatMessageLimit();
      });
      _scrollChatToBottom();
      _markSessionDirty();
      _log(
        'Command: /compress -> compacted_agents=$compactedCount, max_tokens=$maxTokens',
      );
      return true;
    }

    if (command == '/reload_agent') {
      await _loadAgentProfiles();
      final names = _agentProfiles.map((p) => p.name).join(', ');
      setState(() {
        _messages.add(
          ChatMessage(
            text:
                'Agent profiles reloaded: ${names.isEmpty ? "(none)" : names}',
            isUser: false,
          ),
        );
        _enforceChatMessageLimit();
      });
      _scrollChatToBottom();
      _markSessionDirty();
      _log('Command: /reload_agent');
      return true;
    }

    if (command == '/reload_skill') {
      await _loadSkills();
      final names = _skills.map((s) => s.name).join(', ');
      setState(() {
        _messages.add(
          ChatMessage(
            text: 'Skills reloaded: ${names.isEmpty ? "(none)" : names}',
            isUser: false,
          ),
        );
        _enforceChatMessageLimit();
      });
      _scrollChatToBottom();
      _markSessionDirty();
      _log('Command: /reload_skill');
      return true;
    }

    setState(() {
      _messages.add(
        ChatMessage(
          text:
              'Unknown command: $input\nAvailable: ${_slashCommands.join(', ')}',
          isUser: false,
        ),
      );
      _enforceChatMessageLimit();
    });
    _scrollChatToBottom();
    _markSessionDirty();
    _log('Unknown command: $input');
    return true;
  }
}
