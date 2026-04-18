import '../model/tool_call.dart';
import '../model/tool_error_code.dart';
import '../model/tool_result.dart';
import 'audit_ledger.dart';
import 'policy_engine.dart';
import 'tool_registry.dart';

/// Orchestrates a single [ToolCall] through policy → validation → handler.
///
/// Step order:
/// 1. Resolve the registered tool (returns `tool_not_found` if missing).
/// 2. Ask the [PolicyEngine] for a decision — return `policy_denied` on
///    deny, `confirmation_required` on requireConfirmation when
///    `confirmed` is `false`.
/// 3. Delegate validation + execution to [ToolRegistry.invokeRegistered].
/// 4. If an [AuditLedger] is supplied, append a record of the outcome.
class InvocationEngine {
  /// Creates a stateless invocation engine. Safe to share across calls.
  const InvocationEngine();

  /// Executes [call] end-to-end, returning the handler's [ToolResult] or a
  /// policy/validation error.
  ///
  /// [confirmed] must be `true` for tools whose policy resolves to
  /// [PolicyDecision.requireConfirmation]; otherwise the call fails with
  /// [ToolErrorCode.confirmationRequired]. When [auditLedger] is non-null,
  /// every outcome (including short-circuits) produces one audit entry.
  Future<ToolResult> handle({
    required ToolCall call,
    required ToolRegistry registry,
    required PolicyEngine policyEngine,
    required bool confirmed,
    AuditLedger? auditLedger,
  }) async {
    final startedAt = DateTime.now();
    final stopwatch = Stopwatch()..start();

    Future<ToolResult> record(
      ToolResult result, {
      ResolvedPolicy? resolved,
    }) async {
      stopwatch.stop();
      await auditLedger?.record(
        call: call,
        result: result,
        resolved: resolved,
        timestamp: startedAt,
        executionDuration: stopwatch.elapsed,
      );
      return result;
    }

    final tool = registry.find(call.toolName);
    if (tool == null) {
      return record(await registry.invoke(call));
    }

    final resolved = await policyEngine.decideDetailed(call.toolName);

    if (resolved.decision == PolicyDecision.deny) {
      return record(
        ToolResult.fail(
          ToolErrorCode.policyDenied,
          'Tool ${call.toolName} is denied.',
        ),
        resolved: resolved,
      );
    }

    if (resolved.decision == PolicyDecision.requireConfirmation && !confirmed) {
      return record(
        ToolResult.fail(
          ToolErrorCode.confirmationRequired,
          'Tool ${call.toolName} requires confirmation.',
        ),
        resolved: resolved,
      );
    }

    return record(
      await registry.invokeRegistered(tool, call),
      resolved: resolved,
    );
  }
}
