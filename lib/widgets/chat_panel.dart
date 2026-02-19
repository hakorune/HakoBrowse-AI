import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../agent_profile_service.dart';
import '../chat_message.dart';

class _FullWidthSpaceFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final composing = newValue.composing;
    final isComposing = composing.isValid && !composing.isCollapsed;
    if (isComposing) return newValue;

    final converted = newValue.text.replaceAll('\u3000', ' ');
    if (converted == newValue.text) return newValue;
    return TextEditingValue(
      text: converted,
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}

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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                    icon:
                        const Icon(Icons.cleaning_services_outlined, size: 18),
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
                    onSelected: isAiResponding
                        ? null
                        : (_) => onSelectAgent(profile.id),
                  );
                }).toList(),
              ),
            ],
          ),
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
        if (showDebug) _DebugLogPanel(logs: debugLogs),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant),
            ),
          ),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: inputController,
            builder: (context, inputValue, _) {
              final slashHints = _matchingSlashCommands(inputValue);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (slashHints.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: slashHints
                              .map(
                                (command) => ActionChip(
                                  avatar: const Icon(Icons.bolt, size: 14),
                                  label: Text(
                                      '$command  ${_commandHint(command)}'),
                                  onPressed: isAiResponding
                                      ? null
                                      : () => _applySlashCommandHint(command),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Tooltip(
                        message: useHtmlContent
                            ? 'Using HTML mode'
                            : 'Using text mode',
                        child: InkWell(
                          onTap: onToggleContentMode,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: useHtmlContent
                                  ? Colors.orange.shade100
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  useHtmlContent
                                      ? Icons.code
                                      : Icons.text_fields,
                                  size: 16,
                                  color: useHtmlContent
                                      ? Colors.orange.shade800
                                      : Colors.grey.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  useHtmlContent ? 'HTML' : 'Text',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: useHtmlContent
                                        ? Colors.orange.shade800
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Focus(
                          onKeyEvent: (_, event) => _handleInputKey(event),
                          child: TextField(
                            controller: inputController,
                            inputFormatters: <TextInputFormatter>[
                              _FullWidthSpaceFormatter(),
                            ],
                            decoration: InputDecoration(
                              hintText:
                                  'Type a message... (Enter send, Shift+Enter newline)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              filled: true,
                              fillColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerLowest,
                            ),
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            minLines: 1,
                            maxLines: 4,
                            enabled: !isAiResponding,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filled(
                        tooltip: isAiResponding ? 'Cancel response' : 'Send',
                        icon: isAiResponding
                            ? const Icon(Icons.stop)
                            : const Icon(Icons.send),
                        onPressed:
                            isAiResponding ? onCancelResponse : onSendMessage,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DebugLogPanel extends StatefulWidget {
  final List<String> logs;

  const _DebugLogPanel({required this.logs});

  @override
  State<_DebugLogPanel> createState() => _DebugLogPanelState();
}

class _DebugLogPanelState extends State<_DebugLogPanel> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _syncTextAndScroll(force: true);
  }

  @override
  void didUpdateWidget(covariant _DebugLogPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTextAndScroll();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncTextAndScroll({bool force = false}) {
    final next = widget.logs.join('\n');
    if (!force && _controller.text == next) return;
    _controller.text = next;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _copyAll() async {
    await Clipboard.setData(ClipboardData(text: _controller.text));
  }

  void _selectAll() {
    final text = _controller.text;
    _controller.selection =
        TextSelection(baseOffset: 0, extentOffset: text.length);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      color: Colors.grey[900],
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Debug log (${widget.logs.length})',
                style: TextStyle(color: Colors.green[200], fontSize: 11),
              ),
              const Spacer(),
              TextButton(
                onPressed: _copyAll,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: Colors.green[200],
                ),
                child: const Text('Copy All'),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: _selectAll,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: Colors.green[200],
                ),
                child: const Text('Select All'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: TextField(
              controller: _controller,
              scrollController: _scrollController,
              readOnly: true,
              maxLines: null,
              expands: true,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Colors.green,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
