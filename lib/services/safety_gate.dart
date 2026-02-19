import 'dart:io';

import 'package:flutter/material.dart';

class SafetyGate {
  static bool isRiskyNavigate(String url) {
    final lower = url.toLowerCase();
    if (lower.startsWith('javascript:')) return true;
    return lower.contains('logout') ||
        lower.contains('delete') ||
        lower.contains('checkout') ||
        lower.contains('payment') ||
        lower.contains('confirm');
  }

  static bool isRiskyScript(String script) {
    final lower = script.toLowerCase();
    return lower.contains('submit(') ||
        lower.contains('.click(') ||
        lower.contains('window.location') ||
        lower.contains('location.href') ||
        lower.contains('fetch(') ||
        lower.contains('xmlhttprequest') ||
        lower.contains('document.cookie') ||
        lower.contains('localstorage') ||
        lower.contains('sessionstorage');
  }

  static bool isRiskyHttpRequest({
    required String method,
    required String url,
    required Map<String, String> headers,
    String? body,
  }) {
    final normalizedMethod = method.toUpperCase().trim();
    final uri = Uri.tryParse(url);
    if (uri == null) return true;
    if (uri.scheme != 'http' && uri.scheme != 'https') return true;

    final riskyMethod = normalizedMethod != 'GET' && normalizedMethod != 'HEAD';
    final sensitiveHeader = headers.keys.any((k) {
      final lower = k.toLowerCase();
      return lower == 'authorization' ||
          lower == 'cookie' ||
          lower == 'set-cookie' ||
          lower == 'x-api-key' ||
          lower == 'proxy-authorization';
    });
    final hasBody = (body ?? '').trim().isNotEmpty;
    final isInsecure = uri.scheme == 'http';
    final privateHost = _isPrivateHost(uri.host);

    return riskyMethod ||
        sensitiveHeader ||
        hasBody ||
        isInsecure ||
        privateHost ||
        isRiskyNavigate(url);
  }

  static bool _isPrivateHost(String host) {
    final lower = host.trim().toLowerCase();
    if (lower.isEmpty) return true;
    if (lower == 'localhost' || lower.endsWith('.local')) return true;

    final ip = InternetAddress.tryParse(lower);
    if (ip == null) return false;

    if (ip.type == InternetAddressType.IPv4) {
      final b = ip.rawAddress;
      if (b.length != 4) return false;
      if (b[0] == 10) return true;
      if (b[0] == 127) return true;
      if (b[0] == 192 && b[1] == 168) return true;
      if (b[0] == 172 && b[1] >= 16 && b[1] <= 31) return true;
      if (b[0] == 169 && b[1] == 254) return true;
      return false;
    }

    if (ip.type == InternetAddressType.IPv6) {
      return ip.isLoopback || ip.isLinkLocal;
    }

    return false;
  }

  static Future<bool> confirm({
    required BuildContext context,
    required bool enabled,
    required String title,
    required String summary,
  }) async {
    if (!enabled) return true;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SelectableText(summary),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Block'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Allow once'),
          ),
        ],
      ),
    );
    return approved == true;
  }
}
