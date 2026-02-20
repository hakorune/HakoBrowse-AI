import 'package:flutter/material.dart';

import '../models/skill_definition.dart';

class SkillsPanel extends StatelessWidget {
  final List<SkillDefinition> skills;
  final Set<String> availableAuthProfileIds;
  final void Function(String skillId, bool enabled) onToggle;
  final VoidCallback onCreateSkill;
  final Future<void> Function(SkillDefinition skill) onEditSkill;
  final Future<void> Function(SkillDefinition skill) onDeleteSkill;
  final Future<void> Function() onManageAuthProfiles;
  final Future<void> Function() onReloadSkills;

  const SkillsPanel({
    super.key,
    required this.skills,
    required this.availableAuthProfileIds,
    required this.onToggle,
    required this.onCreateSkill,
    required this.onEditSkill,
    required this.onDeleteSkill,
    required this.onManageAuthProfiles,
    required this.onReloadSkills,
  });

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (skills.isEmpty) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No skills found in private/skills.\nCreate your first skill.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    } else {
      content = ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: skills.length,
        itemBuilder: (context, index) {
          final skill = skills[index];
          final tools = skill.allowedTools.isEmpty
              ? 'ALL TOOLS'
              : skill.allowedTools.join(', ');
          final requiredAuthProfiles = _extractAuthProfiles(skill.body);
          final availableLower =
              availableAuthProfileIds.map((e) => e.toLowerCase()).toSet();
          final missingAuthProfiles = requiredAuthProfiles
              .where((id) => !availableLower.contains(id.toLowerCase()))
              .toList(growable: false);
          final descriptionPreview = _previewText(skill.description, max: 120);
          final bodyPreview = skill.body.trim().isEmpty
              ? '(no body)'
              : _previewText(skill.body, max: 160);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onSecondaryTapDown: (details) {
              _showSkillContextMenu(
                context: context,
                globalPosition: details.globalPosition,
                skill: skill,
              );
            },
            child: Card(
              child: Column(
                children: [
                  SwitchListTile(
                    value: skill.enabled,
                    onChanged: (v) => onToggle(skill.id, v),
                    title: Text(skill.name),
                    subtitle: Text(
                      '$descriptionPreview\nAllowedTools: $tools\n$bodyPreview',
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: true,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => onEditSkill(skill),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => onDeleteSkill(skill),
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('Delete'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: onManageAuthProfiles,
                          icon: const Icon(Icons.vpn_key_outlined, size: 16),
                          label: const Text('Profiles'),
                        ),
                        const Spacer(),
                        Text(
                          skill.id,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (skill.enabled && missingAuthProfiles.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color:
                                Theme.of(context).colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Missing auth profile: ${missingAuthProfiles.join(', ')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: [
              FilledButton.icon(
                onPressed: onCreateSkill,
                icon: const Icon(Icons.add),
                label: const Text('New Skill'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onReloadSkills,
                icon: const Icon(Icons.refresh),
                label: const Text('Reload'),
              ),
            ],
          ),
        ),
        Expanded(child: content),
      ],
    );
  }

  String _previewText(String value, {required int max}) {
    final compact = value.replaceAll('\r\n', '\n').replaceAll('\n', ' ').trim();
    if (compact.isEmpty) return '';
    if (compact.length <= max) return compact;
    return '${compact.substring(0, max)}...';
  }

  List<String> _extractAuthProfiles(String body) {
    final out = <String>{};
    final pattern = RegExp(
      r'''["']auth_profile["']\s*:\s*["']([^"']+)["']''',
      multiLine: true,
    );
    for (final match in pattern.allMatches(body)) {
      final value = (match.group(1) ?? '').trim();
      if (value.isEmpty) continue;
      final lower = value.toLowerCase();
      if (value.contains('<') || value.contains('>')) continue;
      if (lower == 'profile-id' || lower == 'your-profile-id') continue;
      out.add(value);
    }
    return out.toList(growable: false);
  }

  Future<void> _showSkillContextMenu({
    required BuildContext context,
    required Offset globalPosition,
    required SkillDefinition skill,
  }) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
      Offset.zero & overlay.size,
    );
    final items = <PopupMenuEntry<String>>[
      const PopupMenuItem<String>(
        value: 'edit_skill',
        child: Text('Edit Skill'),
      ),
      const PopupMenuItem<String>(
        value: 'delete_skill',
        child: Text('Delete Skill'),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem<String>(
        value: 'manage_profiles',
        child: Text('Manage Profiles...'),
      ),
    ];

    final selected = await showMenu<String>(
        context: context, position: position, items: items);
    if (selected == null) return;
    if (selected == 'manage_profiles') {
      await onManageAuthProfiles();
      return;
    }
    if (selected == 'edit_skill') {
      await onEditSkill(skill);
      return;
    }
    if (selected == 'delete_skill') {
      await onDeleteSkill(skill);
    }
  }
}
