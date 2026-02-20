// ignore_for_file: invalid_use_of_protected_member

part of '../main.dart';

extension _HomeStateSessionStorageExt on _HomePageState {
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
}
