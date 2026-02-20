import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/tool_auth_profile.dart';
import '../ai_models.dart';
import '../services/tool_auth_profile_service.dart';
import '../settings_service.dart';

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
                child: Row(
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
                    if (!widget.persistToolAuthProfiles)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Preview mode: profile changes are runtime-only.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
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
          onPressed: selectedAuthMethod == AuthMethod.apiKey &&
                  apiKeyController.text.trim().isEmpty
              ? null
              : () async {
                  final navigator = Navigator.of(context);
                  if (widget.persistToolAuthProfiles) {
                    await widget.toolAuthProfileService
                        .saveProfiles(_authProfiles);
                  }
                  if (!mounted) return;
                  final maxContentLength =
                      int.tryParse(maxContentController.text.trim()) ?? 50000;
                  final chatMaxMessages =
                      int.tryParse(chatMaxMessagesController.text.trim()) ??
                          300;
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

Future<List<ToolAuthProfile>?> showToolAuthProfilesDialog({
  required BuildContext context,
  required ToolAuthProfileService service,
  required List<ToolAuthProfile> initial,
}) {
  final profiles = initial.map((p) => p.copyWith()).toList(growable: true);
  profiles.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  return showDialog<List<ToolAuthProfile>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Tool API Profiles'),
        content: SizedBox(
          width: 620,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Used by tool calls such as `http_request` with `auth_profile`.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      final created = await _showEditAuthProfileDialog(
                        context: context,
                        service: service,
                        existing: profiles,
                      );
                      if (created == null) return;
                      setState(() {
                        profiles.add(created);
                        profiles.sort((a, b) => a.name
                            .toLowerCase()
                            .compareTo(b.name.toLowerCase()));
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: profiles.isEmpty
                    ? const Text(
                        'No profiles yet.',
                        style: TextStyle(color: Colors.grey),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: profiles.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final profile = profiles[index];
                          final hosts = profile.allowedHosts.join(', ');
                          return ListTile(
                            dense: true,
                            title: Text(profile.name),
                            subtitle: Text(
                              'ID: ${profile.id}\n'
                              '${profile.headerName}: ${profile.valuePrefix} ${profile.maskedKey()}'
                              '${hosts.isEmpty ? '' : '\nHosts: $hosts'}',
                            ),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  tooltip: 'Edit',
                                  onPressed: () async {
                                    final edited =
                                        await _showEditAuthProfileDialog(
                                      context: context,
                                      service: service,
                                      existing: profiles,
                                      initial: profile,
                                    );
                                    if (edited == null) return;
                                    setState(() {
                                      profiles[index] = edited;
                                      profiles.sort((a, b) => a.name
                                          .toLowerCase()
                                          .compareTo(b.name.toLowerCase()));
                                    });
                                  },
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  onPressed: () {
                                    setState(() {
                                      profiles.removeAt(index);
                                    });
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, profiles),
            child: const Text('Done'),
          ),
        ],
      ),
    ),
  );
}

Future<ToolAuthProfile?> _showEditAuthProfileDialog({
  required BuildContext context,
  required ToolAuthProfileService service,
  required List<ToolAuthProfile> existing,
  ToolAuthProfile? initial,
}) {
  final nameController = TextEditingController(text: initial?.name ?? '');
  final apiKeyController = TextEditingController(text: initial?.apiKey ?? '');
  final headerController =
      TextEditingController(text: initial?.headerName ?? 'Authorization');
  final prefixController =
      TextEditingController(text: initial?.valuePrefix ?? 'Bearer');
  final hostsController = TextEditingController(
      text: (initial?.allowedHosts ?? const <String>[]).join(', '));
  String? error;

  return showDialog<ToolAuthProfile>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final previewId = initial == null
            ? service.nextAvailableId(
                desired: nameController.text.trim(),
                existing: existing,
              )
            : service.nextAvailableId(
                desired: nameController.text.trim(),
                existing: existing,
                editingId: initial.id,
              );
        return AlertDialog(
          title: Text(initial == null ? 'Add API Profile' : 'Edit API Profile'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Profile name',
                      border: OutlineInputBorder(),
                      hintText: 'moltbook_main',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Profile ID (use in auth_profile)',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          previewId,
                          style: const TextStyle(
                            fontFamily: 'Consolas',
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: apiKeyController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'API key',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: headerController,
                    decoration: const InputDecoration(
                      labelText: 'Header name',
                      border: OutlineInputBorder(),
                      hintText: 'Authorization',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: prefixController,
                    decoration: const InputDecoration(
                      labelText: 'Header value prefix',
                      border: OutlineInputBorder(),
                      hintText: 'Bearer',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: hostsController,
                    decoration: const InputDecoration(
                      labelText: 'Allowed hosts (comma separated, optional)',
                      border: OutlineInputBorder(),
                      hintText: 'www.moltbook.com, api.example.com',
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
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
              onPressed: () {
                final name = nameController.text.trim();
                final key = apiKeyController.text.trim();
                final header = headerController.text.trim();
                final prefix = prefixController.text.trim();
                final hosts = hostsController.text
                    .split(',')
                    .map((s) => s.trim().toLowerCase())
                    .where((s) => s.isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort();

                if (name.isEmpty) {
                  setState(() => error = 'Profile name is required.');
                  return;
                }
                if (key.isEmpty) {
                  setState(() => error = 'API key is required.');
                  return;
                }
                if (header.isEmpty) {
                  setState(() => error = 'Header name is required.');
                  return;
                }
                final resolvedId = initial == null
                    ? service.nextAvailableId(desired: name, existing: existing)
                    : service.nextAvailableId(
                        desired: name,
                        existing: existing,
                        editingId: initial.id,
                      );
                Navigator.pop(
                  context,
                  ToolAuthProfile(
                    id: resolvedId,
                    name: name,
                    apiKey: key,
                    headerName: header,
                    valuePrefix: prefix,
                    allowedHosts: hosts,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    ),
  ).whenComplete(() {
    nameController.dispose();
    apiKeyController.dispose();
    headerController.dispose();
    prefixController.dispose();
    hostsController.dispose();
  });
}
