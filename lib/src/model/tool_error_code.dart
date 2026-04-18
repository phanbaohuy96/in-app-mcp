/// Stable, machine-readable error codes emitted by the `in_app_mcp` runtime.
///
/// Populated on [ToolResult.code] when [ToolResult.success] is `false`.
/// Downstream UI / telemetry should branch on these constants rather than on
/// the free-form [ToolResult.message].
class ToolErrorCode {
  /// Namespace-only — all members are `static const` strings; do not
  /// instantiate.
  const ToolErrorCode._();

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

  /// `undoFromLedger` was called but the audit ledger is disabled on this
  /// runtime.
  static const auditDisabled = 'audit_disabled';

  /// `undoFromLedger` referenced an id not present in the ledger.
  static const entryNotFound = 'entry_not_found';

  /// `undoFromLedger` was called against an entry that has already been
  /// undone.
  static const alreadyUndone = 'already_undone';

  /// `undoFromLedger` was called against an entry whose original execution
  /// failed — there is no successful side-effect to undo.
  static const nothingToUndo = 'nothing_to_undo';

  /// `undoFromLedger` was called against a tool that has no registered
  /// [ToolUndoer].
  static const undoNotSupported = 'undo_not_supported';
}
