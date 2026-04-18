/// An LLM-produced request to execute a registered tool.
///
/// Adapters translate the LLM's output into a [ToolCall]; the runtime then
/// resolves policy, validates arguments, and invokes the matching handler.
class ToolCall {
  /// Creates a tool call with an [id], [toolName], [arguments], and optional
  /// [requestId] correlating to the LLM exchange that produced it.
  const ToolCall({
    required this.id,
    required this.toolName,
    required this.arguments,
    this.requestId,
  });

  /// Stable identifier for this call — used to anchor UI state (inline cards)
  /// and to correlate results back to a specific proposal.
  final String id;

  /// Name of the registered tool this call should invoke.
  final String toolName;

  /// Structured arguments to pass to the handler. Keys map to the parameters
  /// declared by the matching [ToolDefinition.argumentTypes].
  final Map<String, dynamic> arguments;

  /// Optional identifier of the upstream LLM request, for tracing across
  /// adapter ↔ runtime ↔ handler boundaries.
  final String? requestId;

  /// Parses a [ToolCall] from its [toJson] representation.
  ///
  /// Tolerant of missing / malformed fields: unknown `id` or `toolName`
  /// values become empty strings and a non-map `arguments` value becomes an
  /// empty map.
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

  /// Serialises this call for transport (e.g. to a native bridge or logs).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'toolName': toolName,
      'arguments': arguments,
      if (requestId != null) 'requestId': requestId,
    };
  }
}
