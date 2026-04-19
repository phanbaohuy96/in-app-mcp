import '../model/tool_call.dart';
import '../model/tool_error_code.dart';
import '../model/tool_result.dart';
import 'audit_ledger.dart';
import 'invocation_interceptor.dart';
import 'policy_engine.dart';
import 'tool_registry.dart';

/// Orchestrates a single [ToolCall] through policy → validation → handler.
///
/// Step order:
/// 1. Resolve the registered tool (returns `tool_not_found` if missing).
/// 2. Ask the [PolicyEngine] for a decision and let
///    [InvocationInterceptor.onResolvePolicy] override it.
/// 3. Return `policy_denied` on deny, `confirmation_required` on
///    requireConfirmation when `confirmed` is `false`.
/// 4. Ask each [InvocationInterceptor.beforeExecute] for a veto.
/// 5. Delegate validation + execution to [ToolRegistry.invokeRegistered].
/// 6. Let [InvocationInterceptor.afterExecute] rewrite the result.
/// 7. If an [AuditLedger] is supplied, append a record of the outcome and
///    fan out to [InvocationInterceptor.onAudit] (errors swallowed).
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
  /// [interceptors] run in the order supplied; see [InvocationInterceptor]
  /// for per-hook chain semantics.
  Future<ToolResult> handle({
    required ToolCall call,
    required ToolRegistry registry,
    required PolicyEngine policyEngine,
    required bool confirmed,
    AuditLedger? auditLedger,
    List<InvocationInterceptor> interceptors = const [],
  }) async {
    final startedAt = DateTime.now();
    final stopwatch = Stopwatch()..start();

    Future<ToolResult> record(
      ToolResult result, {
      ResolvedPolicy? resolved,
    }) async {
      stopwatch.stop();
      final entry = await auditLedger?.record(
        call: call,
        result: result,
        resolved: resolved,
        timestamp: startedAt,
        executionDuration: stopwatch.elapsed,
      );
      if (entry != null && interceptors.isNotEmpty) {
        // Fan-out in parallel; swallow per-interceptor exceptions so
        // telemetry failures can't break a successful invocation.
        await Future.wait(
          interceptors.map((i) => i.onAudit(entry).catchError((Object _) {})),
        );
      }
      return result;
    }

    final tool = registry.find(call.toolName);
    if (tool == null) {
      return record(await registry.invoke(call));
    }

    var resolved = await policyEngine.decideDetailed(call.toolName);
    for (final interceptor in interceptors) {
      final override = await interceptor.onResolvePolicy(
        call.toolName,
        resolved,
      );
      if (override != null) resolved = override;
    }

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

    for (final interceptor in interceptors) {
      final veto = await interceptor.beforeExecute(call, resolved);
      if (veto != null) {
        return record(veto, resolved: resolved);
      }
    }

    var result = await registry.invokeRegistered(tool, call);
    for (final interceptor in interceptors) {
      final rewrite = await interceptor.afterExecute(call, result);
      if (rewrite != null) result = rewrite;
    }
    return record(result, resolved: resolved);
  }
}
