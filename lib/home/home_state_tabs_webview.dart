// ignore_for_file: invalid_use_of_protected_member

part of '../main.dart';

extension _HomeStateTabsWebviewExt on _HomePageState {
  Future<int> _createTab({
    String? initialUrl,
    bool activate = true,
  }) async {
    try {
      final controller = WebviewController();
      await controller.initialize();
      await controller.setPopupWindowPolicy(_popupWindowPolicy);
      await controller.addScriptToExecuteOnDocumentCreated(
        _tabBootstrapScript,
      );

      final tab = BrowserTabState(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        controller: controller,
        title: 'New Tab',
        url: initialUrl ?? 'https://www.google.com',
      );

      tab.urlSubscription = controller.url.listen((url) {
        if (!mounted || url.isEmpty) return;
        final index = _tabs.indexWhere((t) => t.id == tab.id);
        if (index < 0) return;
        setState(() {
          _tabs[index] = _tabs[index].copyWith(url: url);
          if (index == _activeTabIndex) {
            _currentUrl = url;
            _urlController.text = url;
          }
        });
        if (index == _activeTabIndex) {
          _syncAllAgentContexts();
          _markSessionDirty(reason: 'active_tab_url_change');
        }
      });

      tab.titleSubscription = controller.title.listen((title) {
        if (!mounted) return;
        final index = _tabs.indexWhere((t) => t.id == tab.id);
        if (index < 0) return;
        if (title.trim().isEmpty) return;
        setState(() {
          _tabs[index] = _tabs[index].copyWith(title: title.trim());
        });
      });

      tab.webMessageSubscription =
          controller.webMessage.listen((message) async {
        await _handleTabWebMessage(controller, message);
      });

      await controller.loadUrl(tab.url);

      if (!mounted) return -1;
      setState(() {
        _tabs.add(tab);
        if (activate) {
          _activeTabIndex = _tabs.length - 1;
          _currentUrl = tab.url;
          _urlController.text = tab.url;
        }
        _isWebViewReady = _tabs.isNotEmpty;
      });
      if (activate) {
        _syncAllAgentContexts();
      }
      _markSessionDirty(reason: 'create_tab', saveSoon: true);
      return _tabs.length - 1;
    } catch (e) {
      _log('Create tab failed: $e');
      return -1;
    }
  }

  Future<void> _handleTabWebMessage(
    WebviewController controller,
    dynamic message,
  ) async {
    final payload = _parseWebMessagePayload(message);
    if (payload == null) return;
    final type = payload['type']?.toString();
    if (type == 'debug_pointer') {
      if (_showDebug) {
        final event = payload['event']?.toString() ?? '';
        final x = payload['x']?.toString() ?? '';
        final y = payload['y']?.toString() ?? '';
        final btn = payload['button']?.toString() ?? '';
        final buttons = payload['buttons']?.toString() ?? '';
        final targetTag = payload['target_tag']?.toString() ?? '';
        final targetPath = payload['target_path']?.toString() ?? '';
        final hitTag = payload['hit_tag']?.toString() ?? '';
        final hitPath = payload['hit_path']?.toString() ?? '';
        final hitPe = payload['hit_pointer_events']?.toString() ?? '';
        final hitZ = payload['hit_z']?.toString() ?? '';
        final href = payload['href']?.toString() ?? '';
        _log(
          'DOM $event: x=$x y=$y b=$btn/$buttons target=$targetTag [$targetPath] hit=$hitTag [$hitPath] pe=$hitPe z=$hitZ${href.isEmpty ? '' : ' href=$href'}',
        );
      }
      return;
    }
    if (type == 'open_url_same_tab') {
      final url = payload['url']?.toString() ?? '';
      if (url.trim().isEmpty) return;
      final source = payload['source']?.toString() ?? '';
      final href = payload['href']?.toString() ?? '';
      _log(
        'Google popup workaround${source.isEmpty ? '' : '[$source]'}: open same tab -> $url${href.isEmpty ? '' : ' (from $href)'}',
      );
      await controller.loadUrl(url);
      return;
    }
    if (type != 'open_in_new_tab') return;
    final url = payload['url']?.toString() ?? '';
    if (url.trim().isEmpty) return;
    if (_showDebug) {
      _log('Open in new tab: $url');
    }
    await _createTab(initialUrl: url, activate: true);
  }

  Map<String, dynamic>? _parseWebMessagePayload(dynamic message) {
    if (message is Map) {
      return message.map((key, value) => MapEntry(key.toString(), value));
    }
    if (message is String) {
      try {
        final decoded = jsonDecode(message);
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
