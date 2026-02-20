import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/tool_auth_profile.dart';
import '../ai_models.dart';
import '../services/tool_auth_profile_service.dart';
import '../settings_service.dart';
import 'tool_auth_profiles_dialog.dart';

export 'tool_auth_profiles_dialog.dart';

part 'settings_dialog_sections.dart';
part 'settings_dialog_state.dart';

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
