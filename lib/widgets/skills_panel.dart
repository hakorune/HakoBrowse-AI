import 'package:flutter/material.dart';

import '../models/skill_definition.dart';

class SkillsPanel extends StatelessWidget {
  final List<SkillDefinition> skills;
  final void Function(String skillId, bool enabled) onToggle;
  final VoidCallback onCreateSkill;
  final Future<void> Function(SkillDefinition skill) onEditSkill;
  final Future<void> Function(SkillDefinition skill) onDeleteSkill;
  final Future<void> Function() onReloadSkills;

  const SkillsPanel({
    super.key,
    required this.skills,
    required this.onToggle,
    required this.onCreateSkill,
    required this.onEditSkill,
    required this.onDeleteSkill,
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
          final descriptionPreview = _previewText(skill.description, max: 120);
          final bodyPreview = skill.body.trim().isEmpty
              ? '(no body)'
              : _previewText(skill.body, max: 160);
          return Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: skill.enabled,
                  onChanged: (v) => onToggle(skill.id, v),
                  title: Text(skill.name),
                  subtitle: Text(
                    '$descriptionPreview\nAllowedTools: $tools\n$bodyPreview',
                    maxLines: 4,
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
              ],
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
}
