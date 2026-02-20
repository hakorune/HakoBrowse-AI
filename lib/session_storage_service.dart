import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionStorageService {
  static const String _sessionKey = 'chat_session_v1';

  Future<void> save(Map<String, dynamic> snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = await compute(_encodeSessionSnapshot, snapshot);
    await prefs.setString(_sessionKey, encoded);
  }

  Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final parsed = jsonDecode(raw);
      if (parsed is Map) {
        return parsed.map((k, v) => MapEntry(k.toString(), v));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }
}

String _encodeSessionSnapshot(Map<String, dynamic> snapshot) {
  return jsonEncode(snapshot);
}
