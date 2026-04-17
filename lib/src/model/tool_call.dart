class ToolCall {
  const ToolCall({
    required this.id,
    required this.toolName,
    required this.arguments,
    this.requestId,
  });

  final String id;
  final String toolName;
  final Map<String, dynamic> arguments;
  final String? requestId;

  factory ToolCall.fromJson(Map<String, dynamic> json) {
    final rawArgs = json['arguments'];
    return ToolCall(
      id: json['id'] as String? ?? '',
      toolName: json['toolName'] as String? ?? '',
      arguments: rawArgs is Map<String, dynamic>
          ? rawArgs
          : Map<String, dynamic>.from(rawArgs as Map? ?? const {}),
      requestId: json['requestId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'toolName': toolName,
      'arguments': arguments,
      if (requestId != null) 'requestId': requestId,
    };
  }
}
