export 'src/model/tool_call.dart';
export 'src/model/tool_definition.dart';
export 'src/model/tool_error_code.dart';
export 'src/model/tool_result.dart';
export 'src/runtime/invocation_engine.dart';
export 'src/runtime/policy_engine.dart';
export 'src/runtime/policy_store.dart';
export 'src/runtime/tool_registry.dart';

import 'src/model/tool_call.dart';
import 'src/model/tool_definition.dart';
import 'src/model/tool_result.dart';
import 'src/runtime/invocation_engine.dart';
import 'src/runtime/policy_engine.dart';
import 'src/runtime/policy_store.dart';
import 'src/runtime/tool_registry.dart';

class InAppMcp {
  InAppMcp({
    PolicyStore? policyStore,
    ToolPolicy defaultPolicy = ToolPolicy.confirm,
  }) : _registry = ToolRegistry(),
       _policyEngine = PolicyEngine(
         policyStore: policyStore ?? InMemoryPolicyStore(),
         defaultPolicy: defaultPolicy,
       ),
       _invocationEngine = InvocationEngine();

  final ToolRegistry _registry;
  final PolicyEngine _policyEngine;
  final InvocationEngine _invocationEngine;

  void registerTool({
    required ToolDefinition definition,
    required ToolHandler handler,
  }) {
    _registry.registerTool(definition: definition, handler: handler);
  }

  List<ToolDefinition> get tools => _registry.listTools();

  Map<String, dynamic> toolsSchemaJson() {
    return {
      'tools': [
        for (final definition in _registry.listTools()) definition.toJsonSchema(),
      ],
    };
  }

  Future<ToolResult> handleToolCall(ToolCall call, {bool confirmed = false}) {
    return _invocationEngine.handle(
      call: call,
      registry: _registry,
      policyEngine: _policyEngine,
      confirmed: confirmed,
    );
  }

  Future<void> setToolPolicy(String toolName, ToolPolicy policy) {
    return _policyEngine.setToolPolicy(toolName, policy);
  }

  Future<ToolPolicy> getToolPolicy(String toolName) {
    return _policyEngine.getToolPolicy(toolName);
  }

  Future<PolicyDecision> getPolicyDecision(String toolName) {
    return _policyEngine.decide(toolName);
  }
}
