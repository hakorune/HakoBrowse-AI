class SkillDefinition {
  final String id;
  final String name;
  final String description;
  final List<String> allowedTools;
  final String body;
  final String path;
  final bool enabled;

  const SkillDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.allowedTools,
    required this.body,
    required this.path,
    required this.enabled,
  });

  SkillDefinition copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? allowedTools,
    String? body,
    String? path,
    bool? enabled,
  }) {
    return SkillDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      allowedTools: allowedTools ?? this.allowedTools,
      body: body ?? this.body,
      path: path ?? this.path,
      enabled: enabled ?? this.enabled,
    );
  }
}
