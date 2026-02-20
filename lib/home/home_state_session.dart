// ignore_for_file: invalid_use_of_protected_member

part of '../main.dart';

extension _HomeStateSessionExt on _HomePageState {
  Future<void> _toggleDebugMode() async {
    if (_showDebug) {
      _log('Debug mode OFF');
      if (!mounted) return;
      setState(() {
        _showDebug = false;
      });
      await _debugLogFileService.flush();
      _markSessionDirty(reason: 'toggle_debug_off', saveSoon: true);
      return;
    }

    if (!mounted) return;
    setState(() {
      _showDebug = true;
    });
    final path = await _debugLogFileService.getLogFilePath();
    _log('Debug mode ON (auto file log: $path)');
    _markSessionDirty(reason: 'toggle_debug_on', saveSoon: true);
  }

  void _log(String message) {
    final timestamp = DateTime.now().toString().substring(11, 23);
    final line = '[$timestamp] $message';
    _debugLogs.add(line);
    const maxLogs = 1200;
    if (_debugLogs.length > maxLogs) {
      _debugLogs.removeRange(0, _debugLogs.length - maxLogs);
    }
    debugPrint('[hakobrowse] $message');
    if (_showDebug) {
      final flushSoon = message.contains('Session save failed') ||
          message.contains('Session restore failed') ||
          message.contains('Skill editor dialog failed');
      _debugLogFileService.appendLine(line, flushSoon: flushSoon);
    }
    if (mounted && _showDebug && !_isDebugUiUpdateMuted()) {
      _requestDebugUiRefresh();
    }
  }

  void _markSessionDirty({
    String reason = 'state_change',
    bool saveSoon = false,
  }) {
    if (_defaultStateMode) return;
    _sessionDirty = true;
    _pendingSessionSaveReason ??= reason;
    if (saveSoon) {
      _queueSessionSave(reason: reason);
    }
  }

  void _muteDebugUiUpdates({
    required Duration duration,
  }) {
    final nextUntil = DateTime.now().add(duration);
    final current = _debugUiMutedUntil;
    if (current == null || current.isBefore(nextUntil)) {
      _debugUiMutedUntil = nextUntil;
    }
  }

  bool _isDebugUiUpdateMuted() {
    if (_isSkillEditorOpen) return true;
    final until = _debugUiMutedUntil;
    if (until == null) return false;
    if (!DateTime.now().isBefore(until)) {
      _debugUiMutedUntil = null;
      return false;
    }
    return true;
  }

  void _requestDebugUiRefresh() {
    if (!mounted) return;
    if (_debugLogUiRefreshDebounce?.isActive ?? false) return;
    _debugLogUiRefreshDebounce = Timer(const Duration(milliseconds: 90), () {
      if (!mounted || !_showDebug || _isDebugUiUpdateMuted()) return;
      setState(() {});
    });
  }

  bool _isSessionSavePaused() {
    final until = _sessionSavePausedUntil;
    if (until == null) return false;
    if (!DateTime.now().isBefore(until)) {
      _sessionSavePausedUntil = null;
      return false;
    }
    return true;
  }

  Duration _sessionSavePauseRemaining() {
    final until = _sessionSavePausedUntil;
    if (until == null) return Duration.zero;
    final diff = until.difference(DateTime.now());
    if (diff.isNegative || diff == Duration.zero) return Duration.zero;
    return diff;
  }

  void _pauseSessionSave({
    required Duration duration,
    required String reason,
  }) {
    final nextUntil = DateTime.now().add(duration);
    final current = _sessionSavePausedUntil;
    if (current == null || current.isBefore(nextUntil)) {
      _sessionSavePausedUntil = nextUntil;
    }
    _log('Session save paused (${duration.inSeconds}s): $reason');
  }

  void _queueSessionSave({
    String reason = 'event',
    Duration delay = const Duration(milliseconds: 900),
  }) {
    if (_defaultStateMode) return;
    var effectiveDelay = delay;
    if (_isSessionSavePaused()) {
      final remaining = _sessionSavePauseRemaining();
      final delayed = remaining + const Duration(milliseconds: 350);
      if (delayed > effectiveDelay) effectiveDelay = delayed;
    }
    _sessionSaveDebounce?.cancel();
    _sessionSaveDebounce = Timer(effectiveDelay, () {
      unawaited(_saveSessionNow(reason: reason));
    });
  }

  void _startSessionAutosaveTimer() {
    _sessionPeriodicSaveTimer?.cancel();
    if (_defaultStateMode) return;
    _sessionPeriodicSaveTimer =
        Timer.periodic(const Duration(seconds: 60), (_) {
      if (!_sessionDirty) return;
      if (_isSessionSavePaused()) return;
      if (_isSkillEditorOpen) {
        _log('Session save deferred: skill editor is open');
        return;
      }
      unawaited(_saveSessionNow(reason: 'periodic'));
    });
  }

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

  Map<String, dynamic> _buildSessionSnapshot() {
    return SessionSnapshotCodec.encode(
      messages: _messages,
      toolTraces: _toolTraces,
      agentContexts: _agentContexts,
      selectedAgentIds: _selectedAgentIds,
      leftTabIndex: _leftTabIndex,
      showDebug: _showDebug,
      useHtmlContent: _useHtmlContent,
      enableSafetyGate: _enableSafetyGate,
      currentUrl: _currentUrl,
      popupPolicy: _popupWindowPolicy.name,
      browserOnlyExperiment: _browserOnlyExperiment,
    );
  }

  Future<void> _saveSessionNow({
    bool force = false,
    String reason = 'event',
  }) async {
    if (_defaultStateMode) return;
    if (!force && !_sessionDirty) return;
    if (!force && _isSessionSavePaused()) {
      _queueSessionSave(
        reason: 'deferred_while_session_save_paused',
        delay: _sessionSavePauseRemaining() + const Duration(milliseconds: 350),
      );
      return;
    }
    if (!force && _isSkillEditorOpen) {
      _queueSessionSave(
        reason: 'deferred_while_skill_editor_open',
        delay: const Duration(seconds: 2),
      );
      return;
    }
    if (_sessionSaveInFlight) return;
    _sessionSaveInFlight = true;
    try {
      final saveReason = force ? reason : (_pendingSessionSaveReason ?? reason);
      final stopwatch = Stopwatch()..start();
      final buildStart = stopwatch.elapsedMilliseconds;
      final snapshot = _buildSessionSnapshot();
      final buildMs = stopwatch.elapsedMilliseconds - buildStart;
      if (buildMs >= 250) {
        _log('Session snapshot build took ${buildMs}ms');
      }
      await _sessionStorageService.save(snapshot);
      final totalMs = stopwatch.elapsedMilliseconds;
      if (totalMs >= 500) {
        _log('Session save took ${totalMs}ms (reason: $saveReason)');
      }
      _sessionDirty = false;
      _pendingSessionSaveReason = null;
      _log('Session saved (reason: $saveReason)');
    } catch (e) {
      _log('Session save failed: $e');
    } finally {
      _sessionSaveInFlight = false;
    }
  }

  Future<void> _restoreSession() async {
    try {
      final snapshot = await _sessionStorageService.load();
      if (snapshot == null) return;
      final data = SessionSnapshotCodec.decode(snapshot);
      data.agentContexts.forEach((id, payload) {
        _contextForAgent(id).loadFromJson(payload);
      });

      final selected = {...data.selectedAgentIds};
      final knownProfileIds = _agentProfiles.map((p) => p.id).toSet();
      selected.removeWhere((id) => !knownProfileIds.contains(id));
      if (selected.isEmpty && _agentProfiles.isNotEmpty) {
        selected.add(_agentProfiles.first.id);
      }

      final restoredCurrentUrl = data.currentUrl;
      if (restoredCurrentUrl.isNotEmpty) {
        _currentUrl = restoredCurrentUrl;
      }
      var restoredPopupPolicy = WebviewPopupWindowPolicy.sameWindow;
      for (final policy in WebviewPopupWindowPolicy.values) {
        if (policy.name == data.popupPolicy) {
          restoredPopupPolicy = policy;
          break;
        }
      }

      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(data.messages);
        _toolTraces
          ..clear()
          ..addAll(data.toolTraces);
        _selectedAgentIds = selected;
        _leftTabIndex = data.leftTabIndex.clamp(0, 4).toInt();
        _showDebug = data.showDebug;
        _useHtmlContent = data.useHtmlContent;
        _enableSafetyGate = data.enableSafetyGate;
        _popupWindowPolicy = restoredPopupPolicy;
        _browserOnlyExperiment = data.browserOnlyExperiment;
        _urlController.text = _currentUrl;
        _enforceChatMessageLimit();
      });
      _syncAllAgentContexts();
      if (_leftTabIndex == 0) {
        _ensureChatBottomAfterViewSwitch();
      }
      await _setPopupWindowPolicy(
        restoredPopupPolicy,
        persist: false,
        emitLog: false,
      );
      final controller = _activeController;
      if (controller != null && _currentUrl.isNotEmpty) {
        await controller.loadUrl(_currentUrl);
      }
      _sessionDirty = false;
      _pendingSessionSaveReason = null;
      _log('Session restored');
    } catch (e) {
      _log('Session restore failed: $e');
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
