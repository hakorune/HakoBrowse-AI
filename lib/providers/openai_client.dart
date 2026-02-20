import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../ai_models.dart';

class OpenAiClient {
  static Stream<AiEvent> chat({
    required AiServiceConfig config,
    required List<Map<String, dynamic>> messages,
    required List<Map<String, dynamic>> tools,
    AiCancelToken? cancelToken,
  }) async* {
    if (cancelToken?.isCancelled == true) {
      throw const AiRequestCancelledException();
    }

    final client = http.Client();

    final openaiMessages = <Map<String, dynamic>>[];
    for (final msg in messages) {
      if (msg['content'] is String) {
        openaiMessages.add({'role': msg['role'], 'content': msg['content']});
      } else {
        openaiMessages.add(msg);
      }
    }
    _debugPrint('OpenAI Request: model=${config.model}');

    void closeClient() {
      try {
        client.close();
      } catch (_) {}
    }

    cancelToken?.addListener(closeClient);

    try {
      var includeUsage = true;
      while (true) {
        final request = http.Request(
            'POST', Uri.parse('${config.baseUrl}/chat/completions'));
        request.headers['Content-Type'] = 'application/json';
        request.headers['Authorization'] = 'Bearer ${config.apiKey}';
        request.body = jsonEncode(_buildOpenAiBody(
          model: config.model,
          messages: openaiMessages,
          tools: tools,
          includeUsage: includeUsage,
        ));

        final response = await client.send(request);
        if (cancelToken?.isCancelled == true) {
          throw const AiRequestCancelledException();
        }
        _debugPrint('Status: ${response.statusCode}');

        if (response.statusCode != 200) {
          final error = await response.stream.bytesToString();
          _debugPrint('Error: $error');
          if (includeUsage &&
              _shouldRetryWithoutUsage(response.statusCode, error)) {
            _debugPrint(
              'Retrying without stream_options.include_usage (endpoint not supported)',
            );
            includeUsage = false;
            continue;
          }
          throw Exception('API Error ${response.statusCode}: $error');
        }

        String currentToolName = '';
        String currentToolArgs = '';

        await for (final chunk in response.stream.transform(utf8.decoder)) {
          if (cancelToken?.isCancelled == true) {
            throw const AiRequestCancelledException();
          }
          for (final line in chunk.split('\n')) {
            if (!line.startsWith('data: ')) continue;
            final data = line.substring(6).trim();
            if (data.isEmpty || data == '[DONE]') continue;

            try {
              final json = jsonDecode(data);
              final usageEvent = _usageFromOpenAiChunk(json);
              if (usageEvent != null) {
                yield usageEvent;
              }

              final delta = json['choices']?[0]?['delta'];
              if (delta == null) continue;

              final content = delta['content'] as String?;
              if (content != null && content.isNotEmpty) {
                yield TextEvent(content);
              }

              final toolCalls = delta['tool_calls'] as List?;
              if (toolCalls != null) {
                for (final tc in toolCalls) {
                  final fn = tc['function'];
                  if (fn?['name'] != null) {
                    currentToolName = fn!['name'];
                    currentToolArgs = '';
                  }
                  if (fn?['arguments'] != null) {
                    currentToolArgs += fn!['arguments'];
                  }
                }
              }

              final finishReason = json['choices']?[0]?['finish_reason'];
              if (finishReason == 'tool_calls' && currentToolName.isNotEmpty) {
                Map<String, dynamic> args = {};
                if (currentToolArgs.isNotEmpty) {
                  try {
                    args = jsonDecode(currentToolArgs);
                  } catch (_) {}
                }
                yield ToolUseEvent(currentToolName, args);
                currentToolName = '';
                currentToolArgs = '';
              }
            } catch (e) {
              _debugPrint('Parse error: $e');
            }
          }
        }
        break;
      }
    } on AiRequestCancelledException {
      return;
    } catch (e) {
      if (cancelToken?.isCancelled == true) {
        return;
      }
      rethrow;
    } finally {
      cancelToken?.removeListener(closeClient);
      closeClient();
    }
  }
}

void _debugPrint(String message) {
  assert(() {
    debugPrint('[OpenAiClient] $message');
    return true;
  }());
}

Map<String, dynamic> _buildOpenAiBody({
  required String model,
  required List<Map<String, dynamic>> messages,
  required List<Map<String, dynamic>> tools,
  required bool includeUsage,
}) {
  final body = <String, dynamic>{
    'model': model,
    'messages': messages,
    'max_tokens': 4096,
    'stream': true,
    'tools': tools,
  };
  if (includeUsage) {
    body['stream_options'] = {'include_usage': true};
  }
  return body;
}

bool _shouldRetryWithoutUsage(int statusCode, String errorText) {
  if (statusCode != 400 && statusCode != 422) return false;
  final lower = errorText.toLowerCase();
  return lower.contains('stream_options') ||
      lower.contains('include_usage') ||
      lower.contains('unknown field') ||
      lower.contains('unexpected') ||
      lower.contains('not supported');
}

UsageEvent? _usageFromOpenAiChunk(dynamic chunk) {
  if (chunk is! Map) return null;
  final usage = chunk['usage'];
  if (usage is! Map) return null;

  final promptDetails = usage['prompt_tokens_details'];
  final input = _asInt(usage['prompt_tokens']);
  final output = _asInt(usage['completion_tokens']);
  final total = _asInt(usage['total_tokens']);
  final cacheRead =
      promptDetails is Map ? _asInt(promptDetails['cached_tokens']) : null;

  if (input == null && output == null && total == null && cacheRead == null) {
    return null;
  }
  return UsageEvent(
    inputTokens: input,
    outputTokens: output,
    totalTokens: total,
    cacheReadTokens: cacheRead,
  );
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
