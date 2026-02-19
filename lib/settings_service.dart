import 'package:shared_preferences/shared_preferences.dart';

import 'ai_models.dart';

enum AuthMethod { apiKey, oauth }

class AppSettings {
  final ApiProvider provider;
  final AuthMethod authMethod;
  final bool experimentalSubscription;
  final String apiKey;
  final String oauthToken;
  final String baseUrl;
  final String model;
  final int maxContentLength;
  final int chatMaxMessages;
  final double leftPanelWidth;

  const AppSettings({
    required this.provider,
    required this.authMethod,
    required this.experimentalSubscription,
    required this.apiKey,
    required this.oauthToken,
    required this.baseUrl,
    required this.model,
    required this.maxContentLength,
    required this.chatMaxMessages,
    required this.leftPanelWidth,
  });

  AppSettings copyWith({
    ApiProvider? provider,
    AuthMethod? authMethod,
    bool? experimentalSubscription,
    String? apiKey,
    String? oauthToken,
    String? baseUrl,
    String? model,
    int? maxContentLength,
    int? chatMaxMessages,
    double? leftPanelWidth,
  }) {
    return AppSettings(
      provider: provider ?? this.provider,
      authMethod: authMethod ?? this.authMethod,
      experimentalSubscription:
          experimentalSubscription ?? this.experimentalSubscription,
      apiKey: apiKey ?? this.apiKey,
      oauthToken: oauthToken ?? this.oauthToken,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      maxContentLength: maxContentLength ?? this.maxContentLength,
      chatMaxMessages: chatMaxMessages ?? this.chatMaxMessages,
      leftPanelWidth: leftPanelWidth ?? this.leftPanelWidth,
    );
  }
}

class SettingsService {
  String defaultBaseUrl(ApiProvider provider) {
    return provider == ApiProvider.anthropic
        ? 'https://api.z.ai/api/anthropic'
        : 'https://api.openai.com/v1';
  }

  String defaultModel(ApiProvider provider) {
    return provider == ApiProvider.anthropic ? 'glm-5' : 'gpt-4o-mini';
  }

  String providerId(ApiProvider provider) {
    return provider == ApiProvider.openai ? 'openai' : 'anthropic';
  }

  ApiProvider providerFromId(String id) {
    return id == 'openai' ? ApiProvider.openai : ApiProvider.anthropic;
  }

  AuthMethod authMethodFromId(String id) {
    return id == 'oauth' ? AuthMethod.oauth : AuthMethod.apiKey;
  }

  String authMethodId(AuthMethod method) {
    return method == AuthMethod.oauth ? 'oauth' : 'api_key';
  }

  String oauthAuthorizeUrl(ApiProvider provider, bool experimentalSubscription) {
    if (provider == ApiProvider.anthropic) {
      if (experimentalSubscription) {
        return 'https://claude.ai/login';
      }
      return 'https://console.anthropic.com/login';
    }
    return 'https://platform.openai.com/login';
  }

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final providerStr = prefs.getString('api_provider') ?? 'anthropic';
    final authMethodStr = prefs.getString('auth_method') ?? 'api_key';
    final apiKey = prefs.getString('api_key') ?? '';
    final oauthToken = prefs.getString('oauth_token') ?? '';
    final baseUrl = prefs.getString('api_base_url') ?? '';
    final model = prefs.getString('api_model') ?? '';
    final experimentalSubscription =
        prefs.getBool('experimental_subscription') ?? false;
    final maxContentLength = prefs.getInt('max_content_length') ?? 50000;
    final chatMaxMessages = prefs.getInt('chat_max_messages') ?? 300;
    final leftPanelWidth = prefs.getDouble('left_panel_width') ?? 400.0;

    final provider = providerFromId(providerStr);
    return AppSettings(
      provider: provider,
      authMethod: authMethodFromId(authMethodStr),
      experimentalSubscription: experimentalSubscription,
      apiKey: apiKey,
      oauthToken: oauthToken,
      baseUrl: baseUrl.isNotEmpty ? baseUrl : defaultBaseUrl(provider),
      model: model.isNotEmpty ? model : defaultModel(provider),
      maxContentLength: maxContentLength,
      chatMaxMessages: chatMaxMessages,
      leftPanelWidth: leftPanelWidth,
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_provider', providerId(settings.provider));
    await prefs.setString('auth_method', authMethodId(settings.authMethod));
    await prefs.setBool(
      'experimental_subscription',
      settings.experimentalSubscription,
    );
    await prefs.setString('api_key', settings.apiKey);
    await prefs.setString('oauth_token', settings.oauthToken);
    await prefs.setString('api_base_url', settings.baseUrl);
    await prefs.setString('api_model', settings.model);
    await prefs.setInt('max_content_length', settings.maxContentLength);
    await prefs.setInt('chat_max_messages', settings.chatMaxMessages);
    await prefs.setDouble('left_panel_width', settings.leftPanelWidth);
  }
}
