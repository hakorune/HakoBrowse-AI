import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/tool_auth_profile.dart';
import '../ai_models.dart';
import '../services/tool_auth_profile_service.dart';
import '../settings_service.dart';
import 'tool_auth_profiles_dialog.dart';

export 'tool_auth_profiles_dialog.dart';

Future<AppSettings?> showSettingsDialog(
  BuildContext context, {
  required AppSettings initial,
  required SettingsService settingsService,
  required ToolAuthProfileService toolAuthProfileService,
  required void Function(String message) log,
  bool persistToolAuthProfiles = true,
}) {
  return showDialog<AppSettings>(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      return _SettingsDialog(
        initial: initial,
        settingsService: settingsService,
        toolAuthProfileService: toolAuthProfileService,
        log: log,
        persistToolAuthProfiles: persistToolAuthProfiles,
      );
    },
  );
}

class _SettingsDialog extends StatefulWidget {
  final AppSettings initial;
  final SettingsService settingsService;
  final ToolAuthProfileService toolAuthProfileService;
  final void Function(String message) log;
  final bool persistToolAuthProfiles;

  const _SettingsDialog({
    required this.initial,
    required this.settingsService,
    required this.toolAuthProfileService,
    required this.log,
    required this.persistToolAuthProfiles,
  });

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late ApiProvider selectedProvider;
  late AuthMethod selectedAuthMethod;
  late bool experimentalSubscription;
  late final TextEditingController apiKeyController;
  late final TextEditingController oauthTokenController;
  late final TextEditingController baseUrlController;
  late final TextEditingController modelController;
  late final TextEditingController maxContentController;
  late final TextEditingController chatMaxMessagesController;
  List<ToolAuthProfile> _authProfiles = const <ToolAuthProfile>[];
  bool _profilesLoading = true;

  @override
  void initState() {
    super.initState();
    selectedProvider = widget.initial.provider;
    selectedAuthMethod = widget.initial.authMethod;
    experimentalSubscription = widget.initial.experimentalSubscription;
    apiKeyController = TextEditingController(text: widget.initial.apiKey);
    oauthTokenController =
        TextEditingController(text: widget.initial.oauthToken);
    baseUrlController = TextEditingController(text: widget.initial.baseUrl);
    modelController = TextEditingController(text: widget.initial.model);
    maxContentController =
        TextEditingController(text: widget.initial.maxContentLength.toString());
    chatMaxMessagesController =
        TextEditingController(text: widget.initial.chatMaxMessages.toString());
    _loadAuthProfiles();
  }

  @override
  void dispose() {
    apiKeyController.dispose();
    oauthTokenController.dispose();
    baseUrlController.dispose();
    modelController.dispose();
    maxContentController.dispose();
    chatMaxMessagesController.dispose();
    super.dispose();
  }

  Future<void> _startBrowserAuth() async {
    final url = widget.settingsService.oauthAuthorizeUrl(
      selectedProvider,
      experimentalSubscription,
    );
    final uri = Uri.tryParse(url);
    if (uri == null) {
      widget.log('OAuth URL parse failed: $url');
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (launched) {
      widget.log('Opened browser auth: $url');
    } else {
      widget.log('Failed to open browser auth: $url');
    }
  }

  Future<void> _loadAuthProfiles() async {
    final profiles = await widget.toolAuthProfileService.loadProfiles();
    if (!mounted) return;
    setState(() {
      _authProfiles = profiles;
      _profilesLoading = false;
    });
  }

  Future<void> _openAuthProfilesDialog() async {
    final updated = await showToolAuthProfilesDialog(
      context: context,
      service: widget.toolAuthProfileService,
      initial: _authProfiles,
    );
    if (updated == null) return;
    if (!mounted) return;
    setState(() {
      _authProfiles = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('API Settings'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber,
                            color: Colors.orange.shade800, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Personal data on pages may be sent to your AI provider. Use at your own risk.',
                            style: TextStyle(
                                color: Colors.orange.shade900, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    if (!widget.persistToolAuthProfiles) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Preview mode: profile changes are runtime-only.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('Provider',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Radio<ApiProvider>(
                    value: ApiProvider.anthropic,
                    groupValue: selectedProvider,
                    onChanged: (v) {
                      setState(() {
                        selectedProvider = v!;
                        if (baseUrlController.text.trim().isEmpty ||
                            baseUrlController.text ==
                                widget.settingsService
                                    .defaultBaseUrl(ApiProvider.openai)) {
                          baseUrlController.text = widget.settingsService
                              .defaultBaseUrl(ApiProvider.anthropic);
                        }
                        if (modelController.text.trim().isEmpty ||
                            modelController.text ==
                                widget.settingsService
                                    .defaultModel(ApiProvider.openai)) {
                          modelController.text = widget.settingsService
                              .defaultModel(ApiProvider.anthropic);
                        }
                      });
                    },
                  ),
                  const Text('Anthropic/GLM'),
                  const SizedBox(width: 16),
                  Radio<ApiProvider>(
                    value: ApiProvider.openai,
                    groupValue: selectedProvider,
                    onChanged: (v) {
                      setState(() {
                        selectedProvider = v!;
                        if (baseUrlController.text.trim().isEmpty ||
                            baseUrlController.text ==
                                widget.settingsService
                                    .defaultBaseUrl(ApiProvider.anthropic)) {
                          baseUrlController.text = widget.settingsService
                              .defaultBaseUrl(ApiProvider.openai);
                        }
                        if (modelController.text.trim().isEmpty ||
                            modelController.text ==
                                widget.settingsService
                                    .defaultModel(ApiProvider.anthropic)) {
                          modelController.text = widget.settingsService
                              .defaultModel(ApiProvider.openai);
                        }
                      });
                    },
                  ),
                  const Text('OpenAI'),
                ],
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.info_outline, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Gemini provider UI support is planned (API key first).',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Auth Method',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              SegmentedButton<AuthMethod>(
                segments: const [
                  ButtonSegment<AuthMethod>(
                    value: AuthMethod.apiKey,
                    label: Text('API Key'),
                    icon: Icon(Icons.vpn_key_outlined),
                  ),
                  ButtonSegment<AuthMethod>(
                    value: AuthMethod.oauth,
                    label: Text('OAuth'),
                    icon: Icon(Icons.account_circle_outlined),
                  ),
                ],
                selected: {selectedAuthMethod},
                onSelectionChanged: (selection) {
                  setState(() {
                    selectedAuthMethod = selection.first;
                  });
                },
              ),
              const SizedBox(height: 8),
              if (selectedProvider == ApiProvider.anthropic &&
                  selectedAuthMethod == AuthMethod.oauth)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: experimentalSubscription,
                  onChanged: (v) {
                    setState(() {
                      experimentalSubscription = v ?? false;
                    });
                  },
                  title: const Text('Use Claude Pro/Max (Experimental)'),
                  subtitle:
                      const Text('Unofficial and may break without notice.'),
                ),
              const SizedBox(height: 12),
              if (selectedAuthMethod == AuthMethod.apiKey)
                TextField(
                  controller: apiKeyController,
                  decoration: const InputDecoration(
                    labelText: 'API Key',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
              if (selectedAuthMethod == AuthMethod.oauth)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: const Text(
                    'Experimental browser auth helper: open provider login, then paste token/code below.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              if (selectedAuthMethod == AuthMethod.oauth) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _startBrowserAuth,
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Start Browser Auth'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: oauthTokenController,
                  decoration: const InputDecoration(
                    labelText: 'OAuth token / code',
                    border: OutlineInputBorder(),
                    helperText:
                        'Paste callback code or token manually (experimental).',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Text('Tool API Profiles',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Register external API keys used by tools (example: `http_request` + `auth_profile`).',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.teal.shade900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed:
                          _profilesLoading ? null : _openAuthProfilesDialog,
                      icon: const Icon(Icons.vpn_key),
                      label: Text(
                        _profilesLoading
                            ? 'Loading profiles...'
                            : 'Manage Profiles (${_authProfiles.length})',
                      ),
                    ),
                    if (_authProfiles.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        _authProfiles
                            .take(3)
                            .map(
                                (p) => '${p.name} [${p.id}] (${p.maskedKey()})')
                            .join('  |  '),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: baseUrlController,
                decoration: const InputDecoration(
                  labelText: 'Base URL',
                  border: OutlineInputBorder(),
                  helperText: 'Default value is usually OK.',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: modelController,
                decoration: InputDecoration(
                  labelText: 'Model',
                  border: const OutlineInputBorder(),
                  helperText: selectedProvider == ApiProvider.anthropic
                      ? 'e.g. glm-5, claude-3-5-sonnet-20241022'
                      : 'e.g. gpt-4o-mini, gpt-4o, gpt-5',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: maxContentController,
                decoration: const InputDecoration(
                  labelText: 'HTML max length',
                  border: OutlineInputBorder(),
                  helperText: 'Recommended: 50000 chars',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: chatMaxMessagesController,
                decoration: const InputDecoration(
                  labelText: 'Chat max messages',
                  border: OutlineInputBorder(),
                  helperText:
                      'Auto-trim oldest messages when limit is exceeded',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final navigator = Navigator.of(context);
            if (widget.persistToolAuthProfiles) {
              await widget.toolAuthProfileService.saveProfiles(_authProfiles);
            }
            if (!mounted) return;
            final maxContentLength =
                int.tryParse(maxContentController.text.trim()) ?? 50000;
            final chatMaxMessages =
                int.tryParse(chatMaxMessagesController.text.trim()) ?? 300;
            final clampedChatMaxMessages =
                chatMaxMessages.clamp(50, 5000).toInt();
            navigator.pop(
              AppSettings(
                provider: selectedProvider,
                authMethod: selectedAuthMethod,
                experimentalSubscription: experimentalSubscription,
                apiKey: apiKeyController.text.trim(),
                oauthToken: oauthTokenController.text.trim(),
                baseUrl: baseUrlController.text.trim(),
                model: modelController.text.trim(),
                maxContentLength: maxContentLength,
                chatMaxMessages: clampedChatMaxMessages,
                leftPanelWidth: widget.initial.leftPanelWidth,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
