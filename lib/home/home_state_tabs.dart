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

  Future<int> _createTab({
    String? initialUrl,
    bool activate = true,
  }) async {
    try {
      final controller = WebviewController();
      await controller.initialize();
      await controller.setPopupWindowPolicy(_popupWindowPolicy);
      await controller.addScriptToExecuteOnDocumentCreated('''
      (function() {
        if (!window.chrome || !window.chrome.webview || !window.chrome.webview.postMessage) return;
        var lastAt = 0;
        function postMessagePayload(payload) {
          try {
            window.chrome.webview.postMessage(JSON.stringify(payload));
          } catch (_) {}
        }
        function asTag(node) {
          if (!node || !node.tagName) return '';
          return String(node.tagName).toLowerCase();
        }
        function asClass(node) {
          if (!node || !node.className) return '';
          var cls = String(node.className).trim();
          if (!cls) return '';
          return cls.length > 80 ? cls.slice(0, 80) + '...' : cls;
        }
        function pathPreview(node) {
          if (!node) return '';
          var out = [];
          var cur = node;
          for (var i = 0; i < 4 && cur; i++) {
            var tag = asTag(cur);
            if (!tag) break;
            var id = cur.id ? ('#' + String(cur.id)) : '';
            out.push(tag + id);
            cur = cur.parentElement;
          }
          return out.join(' > ');
        }
        function postDebugEvent(kind, e) {
          var now = Date.now();
          if (now - lastAt < 40) return;
          lastAt = now;

          var x = Number(e.clientX || 0);
          var y = Number(e.clientY || 0);
          var target = e.target || null;
          var hit = document.elementFromPoint(x, y);
          var hitStyle = null;
          try {
            hitStyle = hit ? window.getComputedStyle(hit) : null;
          } catch (_) {}
          var payload = {
            type: 'debug_pointer',
            event: kind,
            x: x,
            y: y,
            button: Number(e.button || 0),
            buttons: Number(e.buttons || 0),
            target_tag: asTag(target),
            target_class: asClass(target),
            target_path: pathPreview(target),
            hit_tag: asTag(hit),
            hit_class: asClass(hit),
            hit_path: pathPreview(hit),
            hit_pointer_events: hitStyle && hitStyle.pointerEvents ? String(hitStyle.pointerEvents) : '',
            hit_z: hitStyle && hitStyle.zIndex ? String(hitStyle.zIndex) : '',
            href: (target && target.closest && target.closest('a[href]')) ? String(target.closest('a[href]').href || '').slice(0, 240) : ''
          };
          postMessagePayload(payload);
        }
        function findAnchorFromEvent(e) {
          if (!e) return null;
          var target = e.target || null;
          if (target && target.closest) {
            var direct = target.closest('a[href]');
            if (direct && direct.href) return direct;
          }
          var path = null;
          try {
            path = e.composedPath ? e.composedPath() : null;
          } catch (_) {}
          if (!path || !path.length) return null;
          for (var i = 0; i < path.length; i++) {
            var node = path[i];
            if (!node) continue;
            if (node.tagName && String(node.tagName).toLowerCase() === 'a' && node.href) {
              return node;
            }
            if (node.closest) {
              var nested = node.closest('a[href]');
              if (nested && nested.href) return nested;
            }
          }
          return null;
        }
        function isGoogleAccountEntry(href) {
          if (!href) return false;
          var lower = String(href).toLowerCase();
          if (lower.indexOf('accounts.google.com/signoutoptions') >= 0) return true;
          if (lower.indexOf('accounts.google.com/accountchooser') >= 0) return true;
          if (lower.indexOf('accounts.google.com/addsession') >= 0) return true;
          return false;
        }
        function maybeRedirectGoogleAccountChooser(e, source) {
          if (!e) return false;
          var anchor = findAnchorFromEvent(e);
          if (!anchor || !anchor.href) return false;
          var href = String(anchor.href || '');
          if (!isGoogleAccountEntry(href)) return false;
          e.preventDefault();
          e.stopPropagation();
          if (e.stopImmediatePropagation) e.stopImmediatePropagation();
          var continueUrl = '';
          try {
            continueUrl = encodeURIComponent(String(window.location.href || 'https://www.google.com'));
          } catch (_) {}
          var chooser = continueUrl
            ? ('https://accounts.google.com/AccountChooser?continue=' + continueUrl)
            : 'https://accounts.google.com/AccountChooser';
          postMessagePayload({
            type: 'open_url_same_tab',
            url: chooser,
            source: source || '',
            href: href
          });
          return true;
        }
        var lastNewTabAt = 0;
        var lastNewTabUrl = '';
        function postOpenInNewTab(url) {
          if (!url) return;
          var now = Date.now();
          if (url === lastNewTabUrl && (now - lastNewTabAt) < 350) return;
          lastNewTabAt = now;
          lastNewTabUrl = url;
          postMessagePayload({ type: 'open_in_new_tab', url: url });
        }
        function openLinkInNewTabFromEvent(e) {
          var anchor = e.target && e.target.closest ? e.target.closest('a[href]') : null;
          if (!anchor || !anchor.href) return false;
          var href = String(anchor.href || '');
          if (!href) return false;
          if (href.indexOf('javascript:') === 0) return false;
          e.preventDefault();
          e.stopPropagation();
          postOpenInNewTab(href);
          return true;
        }
        document.addEventListener('pointerdown', function(e) {
          if (Number(e.button || 0) === 0 && maybeRedirectGoogleAccountChooser(e, 'pointerdown')) return;
          postDebugEvent('pointerdown', e);
        }, true);
        document.addEventListener('pointerup', function(e) { postDebugEvent('pointerup', e); }, true);
        document.addEventListener('click', function(e) {
          if (maybeRedirectGoogleAccountChooser(e, 'click')) return;
          postDebugEvent('click', e);
        }, true);
        document.addEventListener('auxclick', function(e) {
          if (Number(e.button) !== 1 && Number(e.which) !== 2) return;
          openLinkInNewTabFromEvent(e);
        }, true);
        document.addEventListener('mouseup', function(e) {
          if (Number(e.button) !== 1 && Number(e.which) !== 2) return;
          openLinkInNewTabFromEvent(e);
        }, true);
      })();
      ''');

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
