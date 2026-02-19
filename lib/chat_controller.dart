import 'chat_message.dart';
import 'context_manager.dart';
import 'ai_service.dart';
import 'content_sanitizer.dart';

class ChatController {
  Future<void> processAiResponse({
    required AiService aiService,
    required List<ChatMessage> messages,
    required Future<String> Function(String, Map<String, dynamic>) executeTool,
    required void Function(void Function()) setState,
    required void Function(String) log,
    required ContextManager contextManager,
    required String systemPrompt,
    Set<String>? allowedToolNames,
    String? assistantLabel,
    AiCancelToken? cancelToken,
    required void Function(bool) setAiResponding,
    bool manageRespondingFlag = true,
  }) async {
    final aiMessageIndex = messages.length;
    setState(() {
      messages.add(
        ChatMessage(
          text: '',
          isUser: false,
          isTool: false,
          agentName: assistantLabel,
        ),
      );
    });

    String fullResponse = '';
    final contentBlocks = <Map<String, dynamic>>[];

    try {
      if (cancelToken?.isCancelled == true) {
        throw const AiRequestCancelledException();
      }
      var context = contextManager.buildMessages(systemPrompt: systemPrompt);
      if (context.pruned) {
        log('Context pruned: estimated ${context.estimatedTokens} tokens');
      } else {
        log('Context estimated tokens: ${context.estimatedTokens}');
      }
      if (context.compactRecommended) {
        final compacted = contextManager.compactNow();
        if (compacted) {
          log('Context compacted automatically');
          context = contextManager.buildMessages(systemPrompt: systemPrompt);
          log('Context after compact: ${context.estimatedTokens} tokens');
        }
      }

      log('Sending request to API...');
      final stream = aiService.chat(
        messages: context.messages,
        allowedToolNames: allowedToolNames,
        toolExecutor: executeTool,
        cancelToken: cancelToken,
      );

      await for (final event in stream) {
        if (cancelToken?.isCancelled == true) {
          throw const AiRequestCancelledException();
        }
        if (event is TextEvent) {
          fullResponse += event.text;
          setState(() {
            messages[aiMessageIndex] = ChatMessage(
              text: fullResponse,
              isUser: false,
              agentName: assistantLabel,
              toolCalls: contentBlocks.isNotEmpty ? contentBlocks : null,
            );
          });
        } else if (event is ToolUseEvent) {
          if (cancelToken?.isCancelled == true) {
            throw const AiRequestCancelledException();
          }
          log('Tool use: ${event.toolName}');
          final toolUseId = DateTime.now().microsecondsSinceEpoch.toString();
          contentBlocks.add({
            'type': 'tool_use',
            'id': toolUseId,
            'name': event.toolName,
            'input': event.arguments,
          });

          setState(() {
            messages[aiMessageIndex] = ChatMessage(
              text: fullResponse.isEmpty ? '[tool] ...' : fullResponse,
              isUser: false,
              agentName: assistantLabel,
              toolCalls: List.from(contentBlocks),
            );
          });

          final result = await executeTool(event.toolName, event.arguments);
          if (cancelToken?.isCancelled == true) {
            throw const AiRequestCancelledException();
          }
          final sanitized = sanitizeUntrustedContent(result, sampleLimit: 2);
          final safeResult = sanitized.content;
          if (sanitized.removedLines > 0) {
            final preview = sanitized.removedSamples.join(' | ');
            log(
              preview.isEmpty
                  ? 'Tool result sanitized: removed ${sanitized.removedLines} suspicious lines'
                  : 'Tool result sanitized: removed ${sanitized.removedLines} suspicious lines. Preview: $preview',
            );
          }
          log(
            'Tool result: ${safeResult.length > 100 ? "${safeResult.substring(0, 100)}..." : safeResult}',
          );

          contentBlocks.add({
            'type': 'tool_result',
            'tool_use_id': toolUseId,
            'content': safeResult,
          });
        }
      }

      if (fullResponse.isNotEmpty) {
        contextManager.addAssistantText(fullResponse);
      }

      if (contentBlocks.any((b) => b['type'] == 'tool_result')) {
        if (cancelToken?.isCancelled == true) {
          throw const AiRequestCancelledException();
        }
        contextManager.addAssistantToolUse(
          contentBlocks.where((b) => b['type'] == 'tool_use').toList(),
        );
        final toolResults =
            contentBlocks.where((b) => b['type'] == 'tool_result').toList();
        contextManager.addUserToolResults(toolResults);

        await processAiResponse(
          aiService: aiService,
          messages: messages,
          executeTool: executeTool,
          setState: setState,
          log: log,
          contextManager: contextManager,
          systemPrompt: systemPrompt,
          allowedToolNames: allowedToolNames,
          assistantLabel: assistantLabel,
          cancelToken: cancelToken,
          setAiResponding: setAiResponding,
          manageRespondingFlag: false,
        );
        return;
      }

      log('Response complete: ${fullResponse.length} chars');
    } on AiRequestCancelledException {
      log('Response cancelled');
      setState(() {
        final existing = messages[aiMessageIndex];
        final text = existing.text.trim().isEmpty
            ? '[Cancelled]'
            : '${existing.text}\n\n[Cancelled]';
        messages[aiMessageIndex] = ChatMessage(
          text: text,
          isUser: false,
          isTool: false,
          agentName: existing.agentName ?? assistantLabel,
          toolCalls: existing.toolCalls,
        );
      });
    } catch (e) {
      log('Error: $e');
      setState(() {
        messages[aiMessageIndex] = ChatMessage(
          text: 'Error: $e',
          isUser: false,
          agentName: assistantLabel,
        );
      });
    } finally {
      if (manageRespondingFlag) {
        setAiResponding(false);
      }
    }
  }
}
