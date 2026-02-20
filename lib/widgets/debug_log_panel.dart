import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DebugLogPanel extends StatefulWidget {
  final List<String> logs;

  const DebugLogPanel({super.key, required this.logs});

  @override
  State<DebugLogPanel> createState() => _DebugLogPanelState();
}

class _DebugLogPanelState extends State<DebugLogPanel> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _syncTextAndScroll(force: true);
  }

  @override
  void didUpdateWidget(covariant DebugLogPanel oldWidget) {
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
