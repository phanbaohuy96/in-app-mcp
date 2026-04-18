/// Stable, machine-readable error codes emitted by the `in_app_mcp` runtime.
///
/// Populated on [ToolResult.code] when [ToolResult.success] is `false`.
/// Downstream UI / telemetry should branch on these constants rather than on
/// the free-form [ToolResult.message].
class ToolErrorCode {
  /// No tool is registered for the requested `toolName`.
  static const toolNotFound = 'tool_not_found';

  /// Arguments failed [ToolDefinition.validateArguments] (missing required
  /// key, unknown key when `allowAdditionalArguments` is `false`, or type
  /// mismatch).
  static const invalidArguments = 'invalid_arguments';

  /// The tool's resolved policy is `deny`; execution is blocked.
  static const policyDenied = 'policy_denied';

  /// The tool's policy requires explicit confirmation but the caller did not
  /// pass `confirmed: true` to `InAppMcp.handleToolCall`.
  static const confirmationRequired = 'confirmation_required';
}
