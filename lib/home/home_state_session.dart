// ignore_for_file: invalid_use_of_protected_member

part of '../main.dart';

extension _HomeStateSessionExt on _HomePageState {
  void _scrollChatToBottom({bool animated = true, int retries = 6}) {
    if (!mounted) return;
    void attempt(int left) {
      if (!mounted) return;
      if (!_chatScrollController.hasClients) {
        if (left <= 0) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          attempt(left - 1);
        });
        return;
      }
      final offset = _chatScrollController.position.maxScrollExtent;
      if (animated) {
        _chatScrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      } else {
        _chatScrollController.jumpTo(offset);
      }
      if (left > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_chatScrollController.hasClients) return;
          final latest = _chatScrollController.position.maxScrollExtent;
          if ((_chatScrollController.offset - latest).abs() > 1.0) {
            _chatScrollController.jumpTo(latest);
          }
        });
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      attempt(retries);
    });
  }

  void _ensureChatBottomAfterViewSwitch() {
    const scheduleMs = <int>[0, 32, 96, 180, 320];
    for (final delayMs in scheduleMs) {
      Future<void>.delayed(Duration(milliseconds: delayMs), () {
        if (!mounted || _leftTabIndex != 0) return;
        _scrollChatToBottom(animated: false, retries: 6);
      });
    }
  }

  String _shorten(String value, {int max = 180}) {
    final normalized = value.replaceAll('\n', ' ').replaceAll('\r', ' ').trim();
    if (normalized.length <= max) return normalized;
    return '${normalized.substring(0, max)}...';
  }

  ToolTraceEntry _startToolTrace({
    required String agentId,
    required String toolName,
    required Map<String, dynamic> arguments,
  }) {
    var agentName = agentId;
    for (final p in _agentProfiles) {
      if (p.id == agentId) {
        agentName = p.name;
        break;
      }
    }
    final entry = ToolTraceEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      startedAt: DateTime.now(),
      agentName: agentName,
      toolName: toolName,
      argsPreview: _shorten(jsonEncode(arguments), max: 220),
      status: 'running',
    );
    setState(() {
      _toolTraces.insert(0, entry);
      if (_toolTraces.length > 300) {
        _toolTraces.removeRange(300, _toolTraces.length);
      }
    });
    _markSessionDirty(reason: 'tool_trace_start', saveSoon: true);
    return entry;
  }

  void _finishToolTrace({
    required String traceId,
    required int durationMs,
    required bool success,
    String? resultPreview,
    String? errorMessage,
  }) {
    final index = _toolTraces.indexWhere((t) => t.id == traceId);
    if (index < 0) return;
    final updated = _toolTraces[index].copyWith(
      durationMs: durationMs,
      status: success ? 'ok' : 'error',
      resultPreview:
          resultPreview != null ? _shorten(resultPreview, max: 280) : null,
      errorMessage:
          errorMessage != null ? _shorten(errorMessage, max: 220) : null,
    );
    setState(() {
      _toolTraces[index] = updated;
    });
    _markSessionDirty(reason: 'tool_trace_finish', saveSoon: true);
  }

  ContextManager _contextForAgent(String agentId) {
    return _agentContexts.putIfAbsent(agentId, () {
      final context = ContextManager();
      context.updateCurrentUrl(_currentUrl);
      context.updateMode(_useHtmlContent, _maxContentLength);
      return context;
    });
  }

  void _syncAllAgentContexts() {
    for (final ctx in _agentContexts.values) {
      ctx.updateCurrentUrl(_currentUrl);
      ctx.updateMode(_useHtmlContent, _maxContentLength);
    }
  }

  void _enforceChatMessageLimit() {
    if (_chatMaxMessages < 1) return;
    if (_messages.length <= _chatMaxMessages) return;
    final overflow = _messages.length - _chatMaxMessages;
    _messages.removeRange(0, overflow);
    _log('Chat history trimmed: removed $overflow old message(s)');
  }

  Future<void> _clearConversation() async {
    setState(() {
      _messages.clear();
      _toolTraces.clear();
      for (final ctx in _agentContexts.values) {
        ctx.clear();
        ctx.updateCurrentUrl(_currentUrl);
        ctx.updateMode(_useHtmlContent, _maxContentLength);
      }
    });
    _sessionSaveDebounce?.cancel();
    _sessionDirty = false;
    _pendingSessionSaveReason = null;
    if (!_defaultStateMode) {
      await _sessionStorageService.clear();
    }
    _log('Conversation cleared');
  }
}
