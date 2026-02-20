import 'package:flutter/material.dart';

import '../agent_profile_service.dart';

class ChatPanelAgentsHeader extends StatelessWidget {
  final List<AgentProfile> agentProfiles;
  final Set<String> selectedAgentIds;
  final bool enableSafetyGate;
  final bool isAiResponding;
  final VoidCallback onToggleSafety;
  final VoidCallback onClearChatView;
  final VoidCallback onReloadAgents;
  final VoidCallback onEditActiveAgent;
  final void Function(String agentId) onSelectAgent;

  const ChatPanelAgentsHeader({
    super.key,
    required this.agentProfiles,
    required this.selectedAgentIds,
    required this.enableSafetyGate,
    required this.isAiResponding,
    required this.onToggleSafety,
    required this.onClearChatView,
    required this.onReloadAgents,
    required this.onEditActiveAgent,
    required this.onSelectAgent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom:
              BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Agents',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: enableSafetyGate
                      ? Colors.green.shade100
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  enableSafetyGate ? 'Safety ON' : 'Safety OFF',
                  style: TextStyle(
                    fontSize: 11,
                    color: enableSafetyGate
                        ? Colors.green.shade900
                        : Colors.grey.shade800,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: enableSafetyGate
                    ? 'Disable safety gate'
                    : 'Enable safety gate',
                onPressed: isAiResponding ? null : onToggleSafety,
                icon: Icon(
                  enableSafetyGate ? Icons.shield : Icons.shield_outlined,
                  size: 18,
                ),
              ),
              IconButton(
                tooltip: 'Clear chat view (keep context)',
                onPressed: isAiResponding ? null : onClearChatView,
                icon: const Icon(Icons.cleaning_services_outlined, size: 18),
              ),
              IconButton(
                tooltip: 'Reload agents',
                onPressed: isAiResponding ? null : onReloadAgents,
                icon: const Icon(Icons.refresh, size: 18),
              ),
              IconButton(
                tooltip: 'Edit active agent',
                onPressed: isAiResponding ? null : onEditActiveAgent,
                icon: const Icon(Icons.edit, size: 18),
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: agentProfiles.map((profile) {
              final selected = selectedAgentIds.contains(profile.id);
              return FilterChip(
                label: Text(profile.name),
                selected: selected,
                onSelected:
                    isAiResponding ? null : (_) => onSelectAgent(profile.id),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
