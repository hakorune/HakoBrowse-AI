// ignore_for_file: invalid_use_of_protected_member

part of 'settings_dialog.dart';

extension _SettingsDialogSections on _SettingsDialogState {
  List<Widget> _buildDialogContent() {
    return <Widget>[
      _buildWarningBanner(),
      const SizedBox(height: 12),
      _buildProviderSection(),
      const SizedBox(height: 12),
      _buildAuthMethodSection(),
      const SizedBox(height: 12),
      _buildAuthFieldsSection(),
      const SizedBox(height: 12),
      _buildToolAuthProfilesSection(),
      const SizedBox(height: 8),
      _buildConnectionSettingsSection(),
    ];
  }

  Widget _buildWarningBanner() {
    return Container(
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
                  style: TextStyle(color: Colors.orange.shade900, fontSize: 12),
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
    );
  }

  Widget _buildProviderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Provider', style: TextStyle(fontWeight: FontWeight.bold)),
        Row(
          children: [
            Radio<ApiProvider>(
              value: ApiProvider.anthropic,
              groupValue: selectedProvider,
              onChanged: (v) => _onProviderChanged(v!),
            ),
            const Text('Anthropic/GLM'),
            const SizedBox(width: 16),
            Radio<ApiProvider>(
              value: ApiProvider.openai,
              groupValue: selectedProvider,
              onChanged: (v) => _onProviderChanged(v!),
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
      ],
    );
  }

  Widget _buildAuthMethodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            subtitle: const Text('Unofficial and may break without notice.'),
          ),
      ],
    );
  }

  Widget _buildAuthFieldsSection() {
    if (selectedAuthMethod == AuthMethod.apiKey) {
      return TextField(
        controller: apiKeyController,
        decoration: const InputDecoration(
          labelText: 'API Key',
          border: OutlineInputBorder(),
        ),
        obscureText: true,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            helperText: 'Paste callback code or token manually (experimental).',
          ),
        ),
      ],
    );
  }

  Widget _buildToolAuthProfilesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tool API Profiles',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
                onPressed: _profilesLoading ? null : _openAuthProfilesDialog,
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
                      .map((p) => '${p.name} [${p.id}] (${p.maskedKey()})')
                      .join('  |  '),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionSettingsSection() {
    return Column(
      children: [
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
            helperText: 'Auto-trim oldest messages when limit is exceeded',
          ),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }
}
