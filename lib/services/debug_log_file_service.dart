import 'dart:async';
import 'dart:io';

class DebugLogFileService {
  static const String _logsDirPath = 'private/logs';
  static const int _maxLogBytes = 3 * 1024 * 1024;

  final List<String> _pendingLines = <String>[];
  Timer? _flushTimer;
  bool _flushInFlight = false;
  File? _logFile;
  String? _sessionTag;

  void appendLine(
    String line, {
    bool flushSoon = false,
  }) {
    _pendingLines.add(line);
    if (flushSoon) {
      _flushTimer?.cancel();
      unawaited(flush());
      return;
    }
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(flush());
    });
  }

  Future<String> getLogFilePath() async {
    await _ensureFileReady();
    return _logFile!.path;
  }

  Future<void> flush() async {
    if (_flushInFlight) return;
    if (_pendingLines.isEmpty) return;
    _flushInFlight = true;
    try {
      await _ensureFileReady();
      final file = _logFile!;
      await _rotateIfNeeded(file);
      final lines = List<String>.from(_pendingLines);
      _pendingLines.clear();
      final sink = file.openWrite(mode: FileMode.append);
      for (final line in lines) {
        sink.writeln(line);
      }
      await sink.flush();
      await sink.close();
    } catch (_) {
      // keep logging path best-effort; ignore write failures
    } finally {
      _flushInFlight = false;
    }
  }

  Future<void> dispose() async {
    _flushTimer?.cancel();
    await flush();
  }

  Future<void> _ensureFileReady() async {
    if (_logFile != null) return;
    final dir = Directory(_logsDirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _sessionTag ??= _buildSessionTag();
    _logFile = File('${dir.path}/debug-$_sessionTag.log');
  }

  Future<void> _rotateIfNeeded(File file) async {
    if (!await file.exists()) return;
    final size = await file.length();
    if (size < _maxLogBytes) return;
    final backup = File('${file.path}.1');
    if (await backup.exists()) {
      await backup.delete();
    }
    await file.rename(backup.path);
    _logFile = File(file.path);
  }

  String _buildSessionTag() {
    final now = DateTime.now().toIso8601String();
    return now.replaceAll(':', '-');
  }
}
