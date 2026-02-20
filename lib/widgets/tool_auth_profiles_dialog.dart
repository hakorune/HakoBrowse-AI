import 'package:flutter/material.dart';

import '../models/tool_auth_profile.dart';
import '../services/tool_auth_profile_service.dart';

Future<List<ToolAuthProfile>?> showToolAuthProfilesDialog({
  required BuildContext context,
  required ToolAuthProfileService service,
  required List<ToolAuthProfile> initial,
}) {
  final profiles = initial.map((p) => p.copyWith()).toList(growable: true);
  profiles.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  return showDialog<List<ToolAuthProfile>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Tool API Profiles'),
        content: SizedBox(
          width: 620,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Used by tool calls such as `http_request` with `auth_profile`.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      final created = await _showEditAuthProfileDialog(
                        context: context,
                        service: service,
                        existing: profiles,
                      );
                      if (created == null) return;
                      setState(() {
                        profiles.add(created);
                        profiles.sort((a, b) => a.name
                            .toLowerCase()
                            .compareTo(b.name.toLowerCase()));
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: profiles.isEmpty
                    ? const Text(
                        'No profiles yet.',
                        style: TextStyle(color: Colors.grey),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: profiles.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final profile = profiles[index];
                          final hosts = profile.allowedHosts.join(', ');
                          return ListTile(
                            dense: true,
                            title: Text(profile.name),
                            subtitle: Text(
                              'ID: ${profile.id}\n'
                              '${profile.headerName}: ${profile.valuePrefix} ${profile.maskedKey()}'
                              '${hosts.isEmpty ? '' : '\nHosts: $hosts'}',
                            ),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  tooltip: 'Edit',
                                  onPressed: () async {
                                    final edited =
                                        await _showEditAuthProfileDialog(
                                      context: context,
                                      service: service,
                                      existing: profiles,
                                      initial: profile,
                                    );
                                    if (edited == null) return;
                                    setState(() {
                                      profiles[index] = edited;
                                      profiles.sort((a, b) => a.name
                                          .toLowerCase()
                                          .compareTo(b.name.toLowerCase()));
                                    });
                                  },
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  onPressed: () {
                                    setState(() {
                                      profiles.removeAt(index);
                                    });
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, profiles),
            child: const Text('Done'),
          ),
        ],
      ),
    ),
  );
}

Future<ToolAuthProfile?> _showEditAuthProfileDialog({
  required BuildContext context,
  required ToolAuthProfileService service,
  required List<ToolAuthProfile> existing,
  ToolAuthProfile? initial,
}) {
  final nameController = TextEditingController(text: initial?.name ?? '');
  final apiKeyController = TextEditingController(text: initial?.apiKey ?? '');
  final headerController =
      TextEditingController(text: initial?.headerName ?? 'Authorization');
  final prefixController =
      TextEditingController(text: initial?.valuePrefix ?? 'Bearer');
  final hostsController = TextEditingController(
      text: (initial?.allowedHosts ?? const <String>[]).join(', '));
  String? error;

  return showDialog<ToolAuthProfile>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final previewId = initial == null
            ? service.nextAvailableId(
                desired: nameController.text.trim(),
                existing: existing,
              )
            : service.nextAvailableId(
                desired: nameController.text.trim(),
                existing: existing,
                editingId: initial.id,
              );
        return AlertDialog(
          title: Text(initial == null ? 'Add API Profile' : 'Edit API Profile'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Profile name',
                      border: OutlineInputBorder(),
                      hintText: 'moltbook_main',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Profile ID (use in auth_profile)',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          previewId,
                          style: const TextStyle(
                            fontFamily: 'Consolas',
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: apiKeyController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'API key',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: headerController,
                    decoration: const InputDecoration(
                      labelText: 'Header name',
                      border: OutlineInputBorder(),
                      hintText: 'Authorization',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: prefixController,
                    decoration: const InputDecoration(
                      labelText: 'Header value prefix',
                      border: OutlineInputBorder(),
                      hintText: 'Bearer',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: hostsController,
                    decoration: const InputDecoration(
                      labelText: 'Allowed hosts (comma separated, optional)',
                      border: OutlineInputBorder(),
                      hintText: 'www.moltbook.com, api.example.com',
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final key = apiKeyController.text.trim();
                final header = headerController.text.trim();
                final prefix = prefixController.text.trim();
                final hosts = hostsController.text
                    .split(',')
                    .map((s) => s.trim().toLowerCase())
                    .where((s) => s.isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort();

                if (name.isEmpty) {
                  setState(() => error = 'Profile name is required.');
                  return;
                }
                if (key.isEmpty) {
                  setState(() => error = 'API key is required.');
                  return;
                }
                if (header.isEmpty) {
                  setState(() => error = 'Header name is required.');
                  return;
                }
                final resolvedId = initial == null
                    ? service.nextAvailableId(desired: name, existing: existing)
                    : service.nextAvailableId(
                        desired: name,
                        existing: existing,
                        editingId: initial.id,
                      );
                Navigator.pop(
                  context,
                  ToolAuthProfile(
                    id: resolvedId,
                    name: name,
                    apiKey: key,
                    headerName: header,
                    valuePrefix: prefix,
                    allowedHosts: hosts,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    ),
  ).whenComplete(() {
    nameController.dispose();
    apiKeyController.dispose();
    headerController.dispose();
    prefixController.dispose();
    hostsController.dispose();
  });
}
