typedef ToolExecutor = Future<String> Function(
  String toolName,
  Map<String, dynamic> arguments,
);

enum ApiProvider { anthropic, openai }

class AiServiceConfig {
  final ApiProvider provider;
  final String apiKey;
  final String baseUrl;
  final String model;

  AiServiceConfig({
    required this.provider,
    required this.apiKey,
    required this.baseUrl,
    required this.model,
  });

  factory AiServiceConfig.anthropic({
    required String apiKey,
    String? baseUrl,
    String? model,
  }) {
    return AiServiceConfig(
      provider: ApiProvider.anthropic,
      apiKey: apiKey,
      baseUrl: baseUrl ?? 'https://api.z.ai/api/anthropic',
      model: model ?? 'glm-5',
    );
  }

  factory AiServiceConfig.openai({
    required String apiKey,
    String? baseUrl,
    String? model,
  }) {
    return AiServiceConfig(
      provider: ApiProvider.openai,
      apiKey: apiKey,
      baseUrl: baseUrl ?? 'https://api.openai.com/v1',
      model: model ?? 'gpt-4o-mini',
    );
  }
}

abstract class AiEvent {}

class TextEvent extends AiEvent {
  final String text;
  TextEvent(this.text);
}

class ToolUseEvent extends AiEvent {
  final String toolName;
  final Map<String, dynamic> arguments;
  ToolUseEvent(this.toolName, this.arguments);
}

class AiRequestCancelledException implements Exception {
  const AiRequestCancelledException();

  @override
  String toString() => 'AI request cancelled';
}

class AiCancelToken {
  bool _cancelled = false;
  final List<void Function()> _listeners = <void Function()>[];

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    final listeners = List<void Function()>.from(_listeners);
    _listeners.clear();
    for (final listener in listeners) {
      try {
        listener();
      } catch (_) {}
    }
  }

  void addListener(void Function() listener) {
    if (_cancelled) {
      listener();
      return;
    }
    _listeners.add(listener);
  }

  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }
}
