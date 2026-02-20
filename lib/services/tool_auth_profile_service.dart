import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/tool_auth_profile.dart';

class ToolAuthProfileService {
  static const String _profilesKey = 'tool_auth_profiles_v1';

  Future<List<ToolAuthProfile>> loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profilesKey);
    if (raw == null || raw.trim().isEmpty) return const <ToolAuthProfile>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <ToolAuthProfile>[];
      final out = <ToolAuthProfile>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final profile = ToolAuthProfile.fromJson(
          item.map((k, v) => MapEntry(k.toString(), v)),
        );
        if (profile.id.trim().isEmpty || profile.name.trim().isEmpty) continue;
        out.add(profile);
      }
      out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return out;
    } catch (_) {
      return const <ToolAuthProfile>[];
    }
  }

  Future<void> saveProfiles(List<ToolAuthProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(profiles.map((p) => p.toJson()).toList());
    await prefs.setString(_profilesKey, encoded);
  }

  String normalizeId(String value) {
    final lower = value.trim().toLowerCase();
    final normalized = lower
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (normalized.isEmpty) {
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
    return normalized;
  }

  String nextAvailableId({
    required String desired,
    required List<ToolAuthProfile> existing,
    String? editingId,
  }) {
    final base = normalizeId(desired);
    final used = existing.map((e) => e.id).toSet();
    if (editingId != null) used.remove(editingId);
    if (!used.contains(base)) return base;
    var i = 2;
    while (used.contains('$base-$i')) {
      i += 1;
    }
    return '$base-$i';
  }
}
