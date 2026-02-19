class ChatMessage {
  final String text;
  final bool isUser;
  final bool isTool;
  final String? agentName;
  final List<Map<String, dynamic>>? toolCalls;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.isTool = false,
    this.agentName,
    this.toolCalls,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'is_user': isUser,
      'is_tool': isTool,
      'agent_name': agentName,
      'tool_calls': toolCalls,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>>? parsedToolCalls;
    final rawToolCalls = json['tool_calls'];
    if (rawToolCalls is List) {
      parsedToolCalls = rawToolCalls
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    }
    return ChatMessage(
      text: json['text']?.toString() ?? '',
      isUser: json['is_user'] == true,
      isTool: json['is_tool'] == true,
      agentName: json['agent_name']?.toString(),
      toolCalls: parsedToolCalls,
    );
  }
}
