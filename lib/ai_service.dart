import 'ai_models.dart';
import 'providers/anthropic_client.dart';
import 'providers/openai_client.dart';
import 'services/tool_registry.dart';

export 'ai_models.dart';

class AiService {
  final AiServiceConfig config;

  AiService({required this.config});

  Stream<AiEvent> chat({
    required List<Map<String, dynamic>> messages,
    Set<String>? allowedToolNames,
    ToolExecutor? toolExecutor,
    AiCancelToken? cancelToken,
  }) {
    if (config.provider == ApiProvider.anthropic) {
      return AnthropicClient.chat(
        config: config,
        messages: messages,
        tools: ToolRegistry.anthropicTools(allowedNames: allowedToolNames),
        cancelToken: cancelToken,
      );
    }

    return OpenAiClient.chat(
      config: config,
      messages: messages,
      tools: ToolRegistry.openaiTools(allowedNames: allowedToolNames),
      cancelToken: cancelToken,
    );
  }
}
