part of '../main.dart';

class _SkillEditorDraft {
  final String name;
  final String description;
  final String body;
  final bool enabled;
  final bool allowAllTools;
  final List<String> allowedTools;

  const _SkillEditorDraft({
    required this.name,
    required this.description,
    required this.body,
    required this.enabled,
    required this.allowAllTools,
    required this.allowedTools,
  });
}

class _SkillEditorScreen extends StatefulWidget {
  final SkillDefinition? initial;
  final List<String> toolNames;
  final String defaultBodyTemplate;

  const _SkillEditorScreen({
    required this.initial,
    required this.toolNames,
    required this.defaultBodyTemplate,
  });

  @override
  State<_SkillEditorScreen> createState() => _SkillEditorScreenState();
}

class _SkillEditorScreenState extends State<_SkillEditorScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _bodyController;
  late bool _enabled;
  late bool _allowAllTools;
  late final Set<String> _selectedTools;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial?.name ?? '');
    _descriptionController =
        TextEditingController(text: widget.initial?.description ?? '');
    _bodyController = TextEditingController(
      text: widget.initial?.body ?? widget.defaultBodyTemplate,
    );
    _enabled = widget.initial?.enabled ?? true;
    _allowAllTools =
        widget.initial == null ? true : widget.initial!.allowedTools.isEmpty;
    _selectedTools = {...widget.initial?.allowedTools ?? const <String>[]};
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _clearValidation() {
    if (_validationError == null) return;
    setState(() {
      _validationError = null;
    });
  }

  void _cancel() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();
  }

  void _save() {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final body = _bodyController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _validationError = 'Name is required.';
      });
      return;
    }
    if (!_allowAllTools && _selectedTools.isEmpty) {
      setState(() {
        _validationError =
            'Select at least one tool or enable "Allow all tools".';
      });
      return;
    }
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(
      _SkillEditorDraft(
        name: name,
        description: description,
        body: body,
        enabled: _enabled,
        allowAllTools: _allowAllTools,
        allowedTools: _selectedTools.toList()..sort(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.initial == null ? 'New Skill' : 'Edit Skill';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          onPressed: _cancel,
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.initial != null) ...[
                Text(
                  'Skill ID: ${widget.initial!.id}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: _nameController,
                autocorrect: false,
                enableSuggestions: false,
                spellCheckConfiguration:
                    const SpellCheckConfiguration.disabled(),
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                onChanged: (_) => _clearValidation(),
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLines: 2,
                autocorrect: false,
                enableSuggestions: false,
                spellCheckConfiguration:
                    const SpellCheckConfiguration.disabled(),
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                onChanged: (_) => _clearValidation(),
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _enabled,
                title: const Text('Enabled'),
                onChanged: (v) => setState(() => _enabled = v),
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _allowAllTools,
                title: const Text('Allow all tools'),
                subtitle: const Text('OFF の場合だけ個別にチェック'),
                onChanged: (v) => setState(() => _allowAllTools = v),
              ),
              if (!_allowAllTools)
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 120),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.toolNames
                          .map(
                            (tool) => FilterChip(
                              label: Text(tool),
                              selected: _selectedTools.contains(tool),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedTools.add(tool);
                                  } else {
                                    _selectedTools.remove(tool);
                                  }
                                });
                              },
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: TextField(
                  controller: _bodyController,
                  maxLines: null,
                  expands: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  spellCheckConfiguration:
                      const SpellCheckConfiguration.disabled(),
                  smartDashesType: SmartDashesType.disabled,
                  smartQuotesType: SmartQuotesType.disabled,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  onChanged: (_) => _clearValidation(),
                  decoration: const InputDecoration(
                    labelText: 'SKILL body',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              if (_validationError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _validationError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
