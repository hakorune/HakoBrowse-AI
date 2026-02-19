class ToolDefinition {
  final String name;
  final String description;
  final String risk;
  final Map<String, dynamic> parameters;
  final List<String> required;

  const ToolDefinition({
    required this.name,
    required this.description,
    required this.risk,
    required this.parameters,
    required this.required,
  });
}
