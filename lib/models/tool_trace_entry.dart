class ToolTraceEntry {
  final String id;
  final DateTime startedAt;
  final String agentName;
  final String toolName;
  final String argsPreview;
  final String status;
  final int durationMs;
  final String? resultPreview;
  final String? errorMessage;

  const ToolTraceEntry({
    required this.id,
    required this.startedAt,
    required this.agentName,
    required this.toolName,
    required this.argsPreview,
    required this.status,
    this.durationMs = 0,
    this.resultPreview,
    this.errorMessage,
  });

  ToolTraceEntry copyWith({
    String? id,
    DateTime? startedAt,
    String? agentName,
    String? toolName,
    String? argsPreview,
    String? status,
    int? durationMs,
    String? resultPreview,
    String? errorMessage,
  }) {
    return ToolTraceEntry(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      agentName: agentName ?? this.agentName,
      toolName: toolName ?? this.toolName,
      argsPreview: argsPreview ?? this.argsPreview,
      status: status ?? this.status,
      durationMs: durationMs ?? this.durationMs,
      resultPreview: resultPreview ?? this.resultPreview,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'started_at': startedAt.toIso8601String(),
      'agent_name': agentName,
      'tool_name': toolName,
      'args_preview': argsPreview,
      'status': status,
      'duration_ms': durationMs,
      'result_preview': resultPreview,
      'error_message': errorMessage,
    };
  }

  factory ToolTraceEntry.fromJson(Map<String, dynamic> json) {
    final startedAtRaw = json['started_at']?.toString() ?? '';
    final startedAt =
        DateTime.tryParse(startedAtRaw) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return ToolTraceEntry(
      id: json['id']?.toString() ?? '',
      startedAt: startedAt,
      agentName: json['agent_name']?.toString() ?? '',
      toolName: json['tool_name']?.toString() ?? '',
      argsPreview: json['args_preview']?.toString() ?? '',
      status: json['status']?.toString() ?? 'ok',
      durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
      resultPreview: json['result_preview']?.toString(),
      errorMessage: json['error_message']?.toString(),
    );
  }
}
