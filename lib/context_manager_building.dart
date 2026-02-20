part of 'context_manager.dart';

ContextBuildResult _buildContextMessages(
  ContextManager ctx, {
  required String systemPrompt,
}) {
  final ssotMessage = _buildSsotMessage(ctx);
  final base = <Map<String, dynamic>>[];
  base.add({
    'role': 'system',
    'content': ContextManager._toolOutputSafetySystemMessage
  });
  if (systemPrompt.trim().isNotEmpty) {
    base.add({'role': 'system', 'content': systemPrompt.trim()});
  }
  if (ctx._checkpointSummary.trim().isNotEmpty) {
    base.add({
      'role': 'system',
      'content':
          'COMPACTED CONTEXT SUMMARY (#${ctx._checkpointCount}):\n${ctx._checkpointSummary}',
    });
  }
  base.add({'role': 'system', 'content': ssotMessage});

  final candidate = [...base, ...ctx._history];
  var estimated = _estimateTokens(candidate);

  var pruned = false;
  var working = candidate;
  if (estimated >= ContextManager.pruneTokens) {
    working = _pruneToolResults(working);
    estimated = _estimateTokens(working);
    pruned = true;
  }

  if (estimated >= ContextManager.hardStopTokens) {
    working = _trimOldestTurns(working, ContextManager.hardStopTokens - 15000);
    estimated = _estimateTokens(working);
    pruned = true;
  }

  return ContextBuildResult(
    messages: working,
    estimatedTokens: estimated,
    pruned: pruned,
    compactRecommended: estimated >= ContextManager.compactTokens,
  );
}

bool _compactContext(ContextManager ctx, {required bool force}) {
  if (ctx._history.length < (force ? 2 : 8)) {
    return false;
  }

  final beforeHistoryJson = jsonEncode(ctx._history);
  final beforeCheckpoint = ctx._checkpointSummary;
  const keepRecent = 6;
  final cutoff =
      (ctx._history.length - keepRecent).clamp(0, ctx._history.length);
  if (!force && cutoff <= 0) {
    return false;
  }
  final old = ctx._history.sublist(0, cutoff);
  final recent = ctx._history.sublist(cutoff);

  final summary = _summarize(old);
  if (summary.trim().isNotEmpty) {
    ctx._checkpointSummary = _mergeCheckpointSummary(
      existing: ctx._checkpointSummary,
      incoming: summary,
    );
    ctx._checkpointCount += 1;
  }
  final compactedRecent = _clearOlderToolResults(recent, keepLatest: 1);
  ctx._history
    ..clear()
    ..addAll(compactedRecent);
  final checkpointChanged = beforeCheckpoint != ctx._checkpointSummary;
  final historyChanged = beforeHistoryJson != jsonEncode(ctx._history);
  return checkpointChanged || historyChanged;
}

String _buildSsotMessage(ContextManager ctx) {
  final payload = {
    'type': 'session_state',
    'goal': ctx._ssot['goal'],
    'current_url': ctx._ssot['current_url'],
    'content_mode': ctx._ssot['content_mode'] ?? 'text',
    'max_content_length': ctx._ssot['max_content_length'] ?? 50000,
    'last_tool': ctx._ssot['last_tool'],
    'next_step': ctx._ssot['next_step'],
    'constraints': ctx._ssot['constraints'],
    'confirmed_facts': ctx._ssot['confirmed_facts'],
  };
  return 'SSOT JSON: ${jsonEncode(payload)}';
}

List<Map<String, dynamic>> _pruneToolResults(
    List<Map<String, dynamic>> messages) {
  final out = <Map<String, dynamic>>[];
  for (final msg in messages) {
    final content = msg['content'];
    if (msg['role'] == 'user' && content is List) {
      final reduced = content.map((item) {
        if (item is Map<String, dynamic> && item['type'] == 'tool_result') {
          return {
            ...item,
            'content': '[pruned tool_result: old output cleared]',
          };
        }
        return item;
      }).toList();
      out.add({...msg, 'content': reduced});
    } else {
      out.add(msg);
    }
  }
  return out;
}

List<Map<String, dynamic>> _trimOldestTurns(
  List<Map<String, dynamic>> messages,
  int target,
) {
  final sys = messages.where((m) => m['role'] == 'system').toList();
  final convo = messages.where((m) => m['role'] != 'system').toList();
  var start = 0;
  while (start < convo.length &&
      _estimateTokens([...sys, ...convo.sublist(start)]) > target) {
    start++;
  }
  return [...sys, ...convo.sublist(start)];
}

String _summarize(List<Map<String, dynamic>> old) {
  final users = <String>[];
  final actions = <String>[];
  for (final m in old) {
    if (m['role'] == 'user' && m['content'] is String) {
      final sanitized = sanitizeUntrustedContent(
        m['content'] as String,
        sampleLimit: 0,
      );
      final t = sanitized.content.trim();
      if (t.isNotEmpty) {
        users.add(t.length > 120 ? '${t.substring(0, 120)}...' : t);
      }
    }
    if (m['content'] is List) {
      for (final item in (m['content'] as List)) {
        if (item is Map && item['type'] == 'tool_use' && item['name'] != null) {
          actions.add(item['name'].toString());
        }
      }
    }
  }

  final uniqueActions = actions.toSet().toList();
  return 'Conversation summary: '
      'User topics: ${users.take(5).join(' | ')}. '
      'Tools used: ${uniqueActions.join(', ')}. '
      'Keep helping from current state.';
}

int _estimateTokens(List<Map<String, dynamic>> messages) {
  final chars = jsonEncode(messages).length;
  return (chars / 2.5).ceil();
}

String _clipTextIfNeeded(String text) {
  if (text.length <= ContextManager._maxStoredTextChars) return text;
  return '${text.substring(0, ContextManager._maxStoredTextChars)}\n...[clipped ${text.length - ContextManager._maxStoredTextChars} chars]';
}

String _clipCheckpointSummary(String text) {
  final trimmed = text.trim();
  if (trimmed.length <= ContextManager._maxCheckpointSummaryChars) {
    return trimmed;
  }
  return trimmed
      .substring(trimmed.length - ContextManager._maxCheckpointSummaryChars);
}

String _mergeCheckpointSummary({
  required String existing,
  required String incoming,
}) {
  final a = existing.trim();
  final b = incoming.trim();
  if (b.isEmpty) return _clipCheckpointSummary(a);
  final merged = a.isEmpty ? b : '$a\n\n$b';
  return _clipCheckpointSummary(merged);
}

List<Map<String, dynamic>> _clipToolResults(
    List<Map<String, dynamic>> toolResults) {
  return toolResults.map((item) {
    if (item['type'] != 'tool_result') return item;
    final raw = item['content']?.toString() ?? '';
    if (raw.length <= ContextManager._maxStoredToolResultChars) {
      return item;
    }
    final clipped = raw.substring(0, ContextManager._maxStoredToolResultChars);
    return {
      ...item,
      'content':
          '[tool_result clipped ${raw.length} -> ${ContextManager._maxStoredToolResultChars} chars]\n$clipped',
    };
  }).toList(growable: false);
}

List<Map<String, dynamic>> _clearOlderToolResults(
  List<Map<String, dynamic>> messages, {
  required int keepLatest,
}) {
  if (messages.isEmpty) return messages;
  final toolResultMessageIndexes = <int>[];
  for (var i = 0; i < messages.length; i++) {
    final msg = messages[i];
    if (msg['role'] != 'user') continue;
    final content = msg['content'];
    if (content is! List) continue;
    final hasToolResult = content.any(
      (item) => item is Map && item['type']?.toString() == 'tool_result',
    );
    if (hasToolResult) toolResultMessageIndexes.add(i);
  }
  if (toolResultMessageIndexes.length <= keepLatest) return messages;

  final preserveStart = toolResultMessageIndexes.length - keepLatest;
  final indexesToClear = toolResultMessageIndexes.sublist(0, preserveStart);
  final output = messages.map((m) => Map<String, dynamic>.from(m)).toList();
  for (final idx in indexesToClear) {
    final msg = output[idx];
    final content = msg['content'];
    if (content is! List) continue;
    final rewritten = content.map((item) {
      if (item is Map && item['type']?.toString() == 'tool_result') {
        final map = Map<String, dynamic>.from(
          item.map((k, v) => MapEntry(k.toString(), v)),
        );
        map['content'] = '[Old tool result content cleared]';
        return map;
      }
      if (item is Map) {
        return Map<String, dynamic>.from(
          item.map((k, v) => MapEntry(k.toString(), v)),
        );
      }
      return item;
    }).toList(growable: false);
    msg['content'] = rewritten;
    output[idx] = msg;
  }
  return output;
}
