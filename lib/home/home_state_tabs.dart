// ignore_for_file: invalid_use_of_protected_member

part of '../main.dart';

extension _HomeStateTabsExt on _HomePageState {
  Future<void> _initTabs() async {
    await _createTab(initialUrl: _currentUrl, activate: true);
    if (!mounted) return;
    setState(() {
      _isWebViewReady = _tabs.isNotEmpty;
    });
  }

  Future<void> _closeTab(int index) async {
    if (index < 0 || index >= _tabs.length) return;
    if (_tabs.length == 1) return;
    final tab = _tabs[index];
    await tab.urlSubscription?.cancel();
    await tab.titleSubscription?.cancel();
    await tab.webMessageSubscription?.cancel();
    await tab.controller.dispose();

    if (!mounted) return;
    setState(() {
      _tabs.removeAt(index);
      if (_activeTabIndex >= _tabs.length) {
        _activeTabIndex = _tabs.length - 1;
      } else if (index < _activeTabIndex) {
        _activeTabIndex -= 1;
      }
      final active = _tabs[_activeTabIndex];
      _currentUrl = active.url;
      _urlController.text = active.url;
      _isWebViewReady = _tabs.isNotEmpty;
    });
    _syncAllAgentContexts();
    _markSessionDirty(reason: 'close_tab', saveSoon: true);
  }

  Future<void> _showTabMenu(int tabIndex) async {
    final action = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(120, 110, 0, 0),
      items: const [
        PopupMenuItem(value: 'new_tab', child: Text('New tab')),
        PopupMenuItem(value: 'duplicate_tab', child: Text('Duplicate tab')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'close_tab', child: Text('Close tab')),
        PopupMenuItem(value: 'close_others', child: Text('Close other tabs')),
      ],
    );
    if (action == null) return;
    if (action == 'new_tab') {
      await _createTab(initialUrl: 'https://www.google.com', activate: true);
      return;
    }
    if (action == 'duplicate_tab') {
      await _createTab(initialUrl: _tabs[tabIndex].url, activate: true);
      return;
    }
    if (action == 'close_tab') {
      await _closeTab(tabIndex);
      return;
    }
    if (action == 'close_others') {
      final keepId = _tabs[tabIndex].id;
      final closeTargets = <int>[];
      for (var i = 0; i < _tabs.length; i++) {
        if (_tabs[i].id != keepId) closeTargets.add(i);
      }
      closeTargets.sort((a, b) => b.compareTo(a));
      for (final i in closeTargets) {
        await _closeTab(i);
      }
    }
  }

  void _onResizeLeftPanel(double delta, double maxWidth) {
    final next = (_leftPanelWidth + delta).clamp(280.0, maxWidth * 0.75);
    setState(() {
      _leftPanelWidth = next;
    });
    _layoutSaveDebounce?.cancel();
    _layoutSaveDebounce = Timer(const Duration(milliseconds: 300), () async {
      final updated = _settings.copyWith(leftPanelWidth: _leftPanelWidth);
      if (_defaultStateMode) {
        if (!mounted) return;
        setState(() {
          _settings = updated;
        });
        _log(
          'Left panel width changed (runtime only): ${_leftPanelWidth.toStringAsFixed(0)}',
        );
        return;
      }
      await _settingsService.save(updated);
      if (!mounted) return;
      setState(() {
        _settings = updated;
      });
      _log('Saved left panel width: ${_leftPanelWidth.toStringAsFixed(0)}');
    });
  }

  Future<void> _loadUrl() async {
    final input = _urlController.text.trim();
    if (input.isEmpty) return;

    String url;
    if (input.startsWith('http://') || input.startsWith('https://')) {
      url = input;
    } else if (_looksLikeDomain(input)) {
      url = 'https://$input';
    } else {
      url = 'https://www.google.com/search?q=${Uri.encodeComponent(input)}';
    }
    final controller = _activeController;
    if (controller == null) return;
    await controller.loadUrl(url);
  }

  Future<void> _openGoogleAccountChooser() async {
    final controller = _activeController;
    if (controller == null) return;
    final continueUrl = _currentUrl.trim().isEmpty
        ? 'https://www.google.com'
        : _currentUrl.trim();
    final target =
        'https://accounts.google.com/AccountChooser?continue=${Uri.encodeComponent(continueUrl)}';
    await controller.loadUrl(target);
  }

  bool _looksLikeDomain(String input) {
    final domainPattern = RegExp(
      r'^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z]{2,})+$',
    );
    return domainPattern.hasMatch(input);
  }

  Future<void> _setPopupWindowPolicy(
    WebviewPopupWindowPolicy policy, {
    bool persist = true,
    bool emitLog = true,
  }) async {
    if (mounted) {
      setState(() {
        _popupWindowPolicy = policy;
      });
    } else {
      _popupWindowPolicy = policy;
    }

    var failures = 0;
    for (final tab in _tabs) {
      try {
        await tab.controller.setPopupWindowPolicy(policy);
      } catch (_) {
        failures += 1;
      }
    }

    if (emitLog) {
      final base = 'Popup policy set: ${_popupPolicyLabel(policy)}';
      if (failures > 0) {
        _log('$base (failed to apply on $failures tab(s))');
      } else {
        _log(base);
      }
    }
    if (persist) {
      _markSessionDirty(reason: 'popup_policy_change', saveSoon: true);
    }
  }
}
