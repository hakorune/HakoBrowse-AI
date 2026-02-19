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
