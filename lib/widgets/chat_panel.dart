import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../agent_profile_service.dart';
import '../chat_message.dart';
import 'chat_panel_agents_header.dart';
import 'chat_panel_input_bar.dart';
import 'debug_log_panel.dart';
import 'full_width_space_formatter.dart';

class ChatPanel extends StatelessWidget {
  final List<AgentProfile> agentProfiles;
  final Set<String> selectedAgentIds;
  final bool enableSafetyGate;
  final bool isAiResponding;
  final VoidCallback onToggleSafety;
  final VoidCallback onClearChatView;
  final VoidCallback onReloadAgents;
  final VoidCallback onEditActiveAgent;
  final void Function(String agentId) onSelectAgent;
  final List<ChatMessage> messages;
  final Widget Function(ChatMessage msg) messageBuilder;
  final bool showDebug;
  final List<String> debugLogs;
  final bool useHtmlContent;
  final VoidCallback onToggleContentMode;
  final TextEditingController inputController;
  final ScrollController scrollController;
  final List<String> slashCommands;
  final VoidCallback onSendMessage;
  final VoidCallback onCancelResponse;

  const ChatPanel({
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
    required this.messages,
    required this.messageBuilder,
    required this.showDebug,
    required this.debugLogs,
    required this.useHtmlContent,
    required this.onToggleContentMode,
    required this.inputController,
    required this.scrollController,
    required this.slashCommands,
    required this.onSendMessage,
    required this.onCancelResponse,
  });

  bool _isImeComposing() {
    final composing = inputController.value.composing;
    return composing.isValid && !composing.isCollapsed;
  }

  KeyEventResult _handleInputKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final isEnter = key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter;
    if (!isEnter) return KeyEventResult.ignored;

    if (HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    if (_isImeComposing()) {
      return KeyEventResult.ignored;
    }
    if (isAiResponding || inputController.text.trim().isEmpty) {
      return KeyEventResult.handled;
    }
    onSendMessage();
    return KeyEventResult.handled;
  }

  List<String> _matchingSlashCommands(TextEditingValue value) {
    final query = _slashQuery(value.text);
    if (query == null) return const <String>[];
    return slashCommands
        .where((cmd) => cmd.toLowerCase().startsWith(query))
        .take(6)
        .toList(growable: false);
  }

  String? _slashQuery(String text) {
    final trimmed = text.trimLeft();
    if (!trimmed.startsWith('/')) return null;
    final firstToken = trimmed.split(RegExp(r'\s+')).first;
    if (firstToken.isEmpty || !firstToken.startsWith('/')) return null;
    return firstToken.toLowerCase();
  }

  String _commandHint(String command) {
    switch (command) {
      case '/clear':
        return 'Clear conversation';
      case '/compress':
        return 'Compact context';
      case '/reload_agent':
        return 'Reload agent profiles';
      case '/reload_skill':
        return 'Reload skills';
      default:
        return 'Command';
    }
  }

  void _applySlashCommandHint(String command) {
    final current = inputController.text;
    final trimmed = current.trimLeft();
    var remainder = '';
    final spaceIndex = trimmed.indexOf(' ');
    if (spaceIndex > 0 && spaceIndex < trimmed.length - 1) {
      remainder = trimmed.substring(spaceIndex + 1).trimLeft();
    }
    final text = remainder.isEmpty ? '$command ' : '$command $remainder';
    inputController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ChatPanelAgentsHeader(
          agentProfiles: agentProfiles,
          selectedAgentIds: selectedAgentIds,
          enableSafetyGate: enableSafetyGate,
          isAiResponding: isAiResponding,
          onToggleSafety: onToggleSafety,
          onClearChatView: onClearChatView,
          onReloadAgents: onReloadAgents,
          onEditActiveAgent: onEditActiveAgent,
          onSelectAgent: onSelectAgent,
        ),
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text('Talk with AI',
                          style: TextStyle(color: Colors.grey[500])),
                      const SizedBox(height: 8),
                      Text(
                        'Try: summarize this page',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) =>
                      messageBuilder(messages[index]),
                ),
        ),
        if (showDebug) DebugLogPanel(logs: debugLogs),
        ChatPanelInputBar(
          useHtmlContent: useHtmlContent,
          isAiResponding: isAiResponding,
          onToggleContentMode: onToggleContentMode,
          inputController: inputController,
          inputFormatters: <TextInputFormatter>[
            FullWidthSpaceFormatter(),
          ],
          onHandleInputKey: _handleInputKey,
          slashHintsBuilder: _matchingSlashCommands,
          commandHintBuilder: _commandHint,
          onApplySlashHint: _applySlashCommandHint,
          onSendMessage: onSendMessage,
          onCancelResponse: onCancelResponse,
        ),
      ],
    );
  }
}
