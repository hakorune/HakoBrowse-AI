import 'package:flutter/material.dart';

import '../models/tool_definition.dart';

class ToolsPanel extends StatelessWidget {
  final List<ToolDefinition> tools;

  const ToolsPanel({super.key, required this.tools});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: tools.length,
      itemBuilder: (context, index) {
        final tool = tools[index];
        final requiredLabel = tool.required.isEmpty ? '-' : tool.required.join(', ');
        final params = tool.parameters.keys.join(', ');
        return Card(
          child: ListTile(
            title: Text(tool.name),
            subtitle: Text(
              '${tool.description}\nRisk: ${tool.risk}\nRequired: $requiredLabel\nParams: ${params.isEmpty ? "-" : params}',
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
