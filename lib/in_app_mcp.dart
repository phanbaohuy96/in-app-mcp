/// In-app MCP-style tool execution runtime for Flutter with policy
/// controls.
///
/// Exposes the [InAppMcp] facade plus the supporting model, policy, and
/// runtime types. See the project README for a walkthrough and the
/// `doc/` folder for architecture / API details.
library;

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

/// Entry-point facade composing the registry, policy engine, and invocation
/// engine behind a small public API.
///
/// A single instance typically lives for the lifetime of the app. Register
/// every tool on startup, then call [handleToolCall] whenever an LLM adapter
/// produces a [ToolCall].
///
/// ```dart
/// final mcp = InAppMcp(defaultPolicy: ToolPolicy.confirm);
/// mcp.registerTool(definition: echoDefinition, handler: echoHandler);
///
/// final result = await mcp.handleToolCall(call, confirmed: true);
/// ```
class InAppMcp {
  /// Creates a new runtime.
  ///
  /// [policyStore] defaults to an [InMemoryPolicyStore]. [defaultPolicy]
  /// governs any tool that has no explicit stored policy yet.
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

  /// Registers [handler] as the implementation for [definition].
  ///
  /// Re-registering under the same [ToolDefinition.name] replaces the prior
  /// entry.
  void registerTool({
    required ToolDefinition definition,
    required ToolHandler handler,
  }) {
    _registry.registerTool(definition: definition, handler: handler);
  }

  /// Unmodifiable snapshot of every currently-registered [ToolDefinition].
  List<ToolDefinition> get tools => _registry.listTools();

  /// Returns an OpenAI-function-calling-style payload listing every
  /// registered tool's JSON schema under the `tools` key.
  ///
  /// Useful for feeding the tool catalog to an LLM adapter in a single call.
  Map<String, dynamic> toolsSchemaJson() {
    return {
      'tools': [
        for (final definition in _registry.listTools())
          definition.toJsonSchema(),
      ],
    };
  }

  /// Executes [call] end-to-end: resolves policy, validates arguments,
  /// invokes the handler, and returns a [ToolResult].
  ///
  /// Pass `confirmed: true` when the user has explicitly approved a call
  /// whose policy is [ToolPolicy.confirm].
  Future<ToolResult> handleToolCall(ToolCall call, {bool confirmed = false}) {
    return _invocationEngine.handle(
      call: call,
      registry: _registry,
      policyEngine: _policyEngine,
      confirmed: confirmed,
    );
  }

  /// Persists [policy] for [toolName] in the backing [PolicyStore].
  Future<void> setToolPolicy(String toolName, ToolPolicy policy) {
    return _policyEngine.setToolPolicy(toolName, policy);
  }

  /// Reads the effective [ToolPolicy] for [toolName], falling back to the
  /// runtime's `defaultPolicy`.
  Future<ToolPolicy> getToolPolicy(String toolName) {
    return _policyEngine.getToolPolicy(toolName);
  }

  /// Resolves [toolName]'s stored policy into a runtime [PolicyDecision].
  Future<PolicyDecision> getPolicyDecision(String toolName) {
    return _policyEngine.decide(toolName);
  }
}
