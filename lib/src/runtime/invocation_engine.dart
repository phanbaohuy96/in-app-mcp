import '../model/tool_call.dart';
import '../model/tool_error_code.dart';
import '../model/tool_result.dart';
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
class InvocationEngine {
  /// Creates a stateless invocation engine. Safe to share across calls.
  const InvocationEngine();

  /// Executes [call] end-to-end, returning the handler's [ToolResult] or a
  /// policy/validation error.
  ///
  /// [confirmed] must be `true` for tools whose policy resolves to
  /// [PolicyDecision.requireConfirmation]; otherwise the call fails with
  /// [ToolErrorCode.confirmationRequired].
  Future<ToolResult> handle({
    required ToolCall call,
    required ToolRegistry registry,
    required PolicyEngine policyEngine,
    required bool confirmed,
  }) async {
    final tool = registry.find(call.toolName);
    if (tool == null) {
      return registry.invoke(call);
    }

    final policyDecision = await policyEngine.decide(call.toolName);

    if (policyDecision == PolicyDecision.deny) {
      return ToolResult.fail(
        ToolErrorCode.policyDenied,
        'Tool ${call.toolName} is denied.',
      );
    }

    if (policyDecision == PolicyDecision.requireConfirmation && !confirmed) {
      return ToolResult.fail(
        ToolErrorCode.confirmationRequired,
        'Tool ${call.toolName} requires confirmation.',
      );
    }

    return registry.invokeRegistered(tool, call);
  }
}
