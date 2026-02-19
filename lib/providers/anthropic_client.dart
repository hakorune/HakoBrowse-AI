import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../ai_models.dart';

class AnthropicClient {
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
    final request =
        http.Request('POST', Uri.parse('${config.baseUrl}/v1/messages'));
    request.headers['Content-Type'] = 'application/json';
    request.headers['x-api-key'] = config.apiKey;
    request.headers['anthropic-version'] = '2023-06-01';

    final systemParts = <String>[];
    final anthropicMessages = <Map<String, dynamic>>[];
    for (final msg in messages) {
      final role = msg['role']?.toString() ?? '';
      final content = msg['content'];

      if (role == 'system') {
        if (content is String && content.trim().isNotEmpty) {
          systemParts.add(content.trim());
        } else if (content != null) {
          systemParts.add(jsonEncode(content));
        }
        continue;
      }

      if (content is String) {
        anthropicMessages.add({'role': role, 'content': content});
      } else if (content != null) {
        anthropicMessages.add({'role': role, 'content': content});
      }
    }

    final body = <String, dynamic>{
      'model': config.model,
      'messages': anthropicMessages,
      'max_tokens': 4096,
      'stream': true,
      'tools': tools,
    };
    if (systemParts.isNotEmpty) {
      body['system'] = systemParts.join('\n\n');
    }

    request.body = jsonEncode(body);
    _debugPrint('Anthropic Request: model=${config.model}');

    void closeClient() {
      try {
        client.close();
      } catch (_) {}
    }

    cancelToken?.addListener(closeClient);

    try {
      final response = await client.send(request);
      if (cancelToken?.isCancelled == true) {
        throw const AiRequestCancelledException();
      }
      _debugPrint('Status: ${response.statusCode}');

      if (response.statusCode != 200) {
        final error = await response.stream.bytesToString();
        _debugPrint('Error: $error');
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
          if (data.isEmpty) continue;

          try {
            final json = jsonDecode(data);
            final type = json['type'];

            if (type == 'content_block_delta') {
              final delta = json['delta'];
              if (delta?['type'] == 'text_delta') {
                final text = delta!['text'] as String?;
                if (text != null && text.isNotEmpty) yield TextEvent(text);
              } else if (delta?['type'] == 'input_json_delta') {
                currentToolArgs += delta!['partial_json'] ?? '';
              }
            } else if (type == 'content_block_start') {
              final cb = json['content_block'];
              if (cb?['type'] == 'tool_use') {
                currentToolName = cb!['name'] ?? '';
                currentToolArgs = '';
              }
            } else if (type == 'content_block_stop') {
              if (currentToolName.isNotEmpty) {
                Map<String, dynamic> args = {};
                if (currentToolArgs.isNotEmpty) {
                  try {
                    args = jsonDecode(currentToolArgs);
                  } catch (_) {}
                }
                yield ToolUseEvent(currentToolName, args);
              }
              currentToolName = '';
              currentToolArgs = '';
            }
          } catch (e) {
            _debugPrint('Parse error: $e');
          }
        }
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
    debugPrint('[AnthropicClient] $message');
    return true;
  }());
}
