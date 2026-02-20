import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChatPanelInputBar extends StatelessWidget {
  final bool useHtmlContent;
  final bool isAiResponding;
  final VoidCallback onToggleContentMode;
  final TextEditingController inputController;
  final List<TextInputFormatter> inputFormatters;
  final KeyEventResult Function(KeyEvent event) onHandleInputKey;
  final List<String> Function(TextEditingValue value) slashHintsBuilder;
  final String Function(String command) commandHintBuilder;
  final void Function(String command) onApplySlashHint;
  final VoidCallback onSendMessage;
  final VoidCallback onCancelResponse;

  const ChatPanelInputBar({
    super.key,
    required this.useHtmlContent,
    required this.isAiResponding,
    required this.onToggleContentMode,
    required this.inputController,
    required this.inputFormatters,
    required this.onHandleInputKey,
    required this.slashHintsBuilder,
    required this.commandHintBuilder,
    required this.onApplySlashHint,
    required this.onSendMessage,
    required this.onCancelResponse,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: inputController,
        builder: (context, inputValue, _) {
          final slashHints = slashHintsBuilder(inputValue);
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
                                  '$command  ${commandHintBuilder(command)}'),
                              onPressed: isAiResponding
                                  ? null
                                  : () => onApplySlashHint(command),
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
                    message:
                        useHtmlContent ? 'Using HTML mode' : 'Using text mode',
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
                              useHtmlContent ? Icons.code : Icons.text_fields,
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
                      onKeyEvent: (_, event) => onHandleInputKey(event),
                      child: TextField(
                        controller: inputController,
                        inputFormatters: inputFormatters,
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
    );
  }
}
