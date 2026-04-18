/// Structured outcome of a tool invocation.
///
/// Returned by every [ToolHandler] and surfaced to the LLM adapter / UI. A
/// result is either a success (with a human-readable [message] and optional
/// structured [data]) or a failure (additionally carrying a machine-readable
/// [code] — see [ToolErrorCode]).
class ToolResult {
  /// Creates a result directly. Prefer [ToolResult.ok] / [ToolResult.fail] at
  /// call sites.
  const ToolResult({
    required this.success,
    required this.message,
    this.code,
    this.data = const {},
  });

  /// Whether the invocation succeeded.
  final bool success;

  /// Human-readable summary of the outcome.
  final String message;

  /// Machine-readable error code; `null` on success. See [ToolErrorCode] for
  /// the runtime-emitted values.
  final String? code;

  /// Structured payload to surface to downstream consumers (LLM, UI, logs).
  final Map<String, dynamic> data;

  /// Convenience constructor for a successful outcome.
  factory ToolResult.ok(
    String message, {
    Map<String, dynamic> data = const {},
  }) {
    return ToolResult(success: true, message: message, data: data);
  }

  /// Convenience constructor for a failed outcome carrying a [code].
  factory ToolResult.fail(
    String code,
    String message, {
    Map<String, dynamic> data = const {},
  }) {
    return ToolResult(success: false, code: code, message: message, data: data);
  }

  /// Serialises this result. `code` is omitted on success.
  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      if (code != null) 'code': code,
      'data': data,
    };
  }
}
