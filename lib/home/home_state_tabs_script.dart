part of '../main.dart';

const String _tabBootstrapScript = r'''
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
''';
