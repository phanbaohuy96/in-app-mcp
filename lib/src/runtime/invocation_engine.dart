import '../model/tool_call.dart';
import '../model/tool_error_code.dart';
import '../model/tool_result.dart';
import 'policy_engine.dart';
import 'tool_registry.dart';

class InvocationEngine {
  const InvocationEngine();

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
