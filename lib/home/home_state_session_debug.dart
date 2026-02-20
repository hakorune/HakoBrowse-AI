// ignore_for_file: invalid_use_of_protected_member

part of '../main.dart';

extension _HomeStateSessionDebugExt on _HomePageState {
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
}
