part of 'settings_dialog.dart';

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

  void _onProviderChanged(ApiProvider provider) {
    setState(() {
      selectedProvider = provider;
      if (provider == ApiProvider.anthropic) {
        final openAiBaseUrl =
            widget.settingsService.defaultBaseUrl(ApiProvider.openai);
        final openAiModel =
            widget.settingsService.defaultModel(ApiProvider.openai);
        if (baseUrlController.text.trim().isEmpty ||
            baseUrlController.text == openAiBaseUrl) {
          baseUrlController.text =
              widget.settingsService.defaultBaseUrl(ApiProvider.anthropic);
        }
        if (modelController.text.trim().isEmpty ||
            modelController.text == openAiModel) {
          modelController.text =
              widget.settingsService.defaultModel(ApiProvider.anthropic);
        }
      } else {
        final anthropicBaseUrl =
            widget.settingsService.defaultBaseUrl(ApiProvider.anthropic);
        final anthropicModel =
            widget.settingsService.defaultModel(ApiProvider.anthropic);
        if (baseUrlController.text.trim().isEmpty ||
            baseUrlController.text == anthropicBaseUrl) {
          baseUrlController.text =
              widget.settingsService.defaultBaseUrl(ApiProvider.openai);
        }
        if (modelController.text.trim().isEmpty ||
            modelController.text == anthropicModel) {
          modelController.text =
              widget.settingsService.defaultModel(ApiProvider.openai);
        }
      }
    });
  }

  Future<void> _saveAndClose() async {
    final navigator = Navigator.of(context);
    if (widget.persistToolAuthProfiles) {
      await widget.toolAuthProfileService.saveProfiles(_authProfiles);
    }
    if (!mounted) return;
    final maxContentLength =
        int.tryParse(maxContentController.text.trim()) ?? 50000;
    final chatMaxMessages =
        int.tryParse(chatMaxMessagesController.text.trim()) ?? 300;
    final clampedChatMaxMessages = chatMaxMessages.clamp(50, 5000).toInt();
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
            children: _buildDialogContent(),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saveAndClose,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
