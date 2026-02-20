part of 'context_manager.dart';

Map<String, dynamic> _contextToJson(ContextManager ctx) {
  return {
    'history': ctx._history,
    'ssot': ctx._ssot,
    'checkpoint_summary': ctx._checkpointSummary,
    'checkpoint_count': ctx._checkpointCount,
  };
}

void _contextLoadFromJson(ContextManager ctx, Map<String, dynamic> json) {
  final history = json['history'];
  final ssot = json['ssot'];
  ctx._checkpointSummary =
      _clipCheckpointSummary(json['checkpoint_summary']?.toString() ?? '');
  ctx._checkpointCount = (json['checkpoint_count'] as num?)?.toInt() ?? 0;

  ctx._history.clear();
  if (history is List) {
    for (final item in history) {
      if (item is Map) {
        ctx._history.add(
          item.map((k, v) => MapEntry(k.toString(), _normalizeContextValue(v))),
        );
      }
    }
  }
  _normalizeLoadedHistory(ctx);
  final normalized = _clearOlderToolResults(ctx._history, keepLatest: 1);
  ctx._history
    ..clear()
    ..addAll(normalized);

  if (ssot is Map) {
    ctx._ssot.clear();
    ssot.forEach((k, v) {
      ctx._ssot[k.toString()] = _normalizeContextValue(v);
    });
  }
}

dynamic _normalizeContextValue(dynamic value) {
  if (value is Map) {
    final map = <String, dynamic>{};
    value.forEach((k, v) {
      map[k.toString()] = _normalizeContextValue(v);
    });
    return map;
  }
  if (value is List) {
    return value.map(_normalizeContextValue).toList();
  }
  return value;
}

void _normalizeLoadedHistory(ContextManager ctx) {
  for (var i = 0; i < ctx._history.length; i++) {
    final msg = ctx._history[i];
    final role = msg['role']?.toString();
    final content = msg['content'];
    if (content is String) {
      ctx._history[i] = {
        ...msg,
        'content': _clipTextIfNeeded(content),
      };
      continue;
    }
    if (role == 'user' && content is List) {
      final list = content
          .whereType<Map>()
          .map((m) => m
              .map((k, v) => MapEntry(k.toString(), _normalizeContextValue(v))))
          .toList(growable: false);
      ctx._history[i] = {
        ...msg,
        'content': _clipToolResults(list),
      };
    }
  }
}
