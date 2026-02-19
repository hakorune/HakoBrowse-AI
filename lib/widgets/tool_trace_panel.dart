import 'package:flutter/material.dart';

import '../models/tool_trace_entry.dart';

class ToolTracePanel extends StatelessWidget {
  final List<ToolTraceEntry> traces;

  const ToolTracePanel({super.key, required this.traces});

  @override
  Widget build(BuildContext context) {
    if (traces.isEmpty) {
      return Center(
        child: Text(
          'No tool calls yet',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: traces.length,
      itemBuilder: (context, index) {
        final t = traces[index];
        final ok = t.status == 'ok';
        final running = t.status == 'running';
        final statusColor = running
            ? Colors.orange
            : (ok ? Colors.green : Colors.red);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.circle, size: 10, color: statusColor),
                    const SizedBox(width: 6),
                    Text('${t.agentName} · ${t.toolName}'),
                    const Spacer(),
                    Text(
                      running ? 'running' : '${t.durationMs}ms',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SelectableText(
                  'args: ${t.argsPreview}',
                  style: const TextStyle(fontSize: 12),
                ),
                if ((t.resultPreview ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  SelectableText(
                    'result: ${t.resultPreview}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
                if ((t.errorMessage ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  SelectableText(
                    'error: ${t.errorMessage}',
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
