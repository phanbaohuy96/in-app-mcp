import 'policy_store.dart';

/// User-facing policy for a single tool.
///
/// The policy is the author's / user's declared intent; it's resolved by
/// [PolicyEngine.decide] into a [PolicyDecision] at invocation time.
enum ToolPolicy {
  /// Run without prompting the user.
  auto,

  /// Require explicit user confirmation before running.
  confirm,

  /// Never run — block the call outright.
  deny,
}

/// Runtime decision produced by [PolicyEngine.decide] for a given tool.
enum PolicyDecision {
  /// Execute the handler without prompting.
  allow,

  /// Stop and require explicit confirmation before proceeding.
  requireConfirmation,

  /// Block execution and return a `policy_denied` error.
  deny,
}

/// Resolves a [ToolPolicy] for each tool and maps it to a [PolicyDecision].
///
/// The engine reads policy from a [PolicyStore] (persistent or ephemeral) and
/// falls back to [defaultPolicy] when a tool has no stored policy yet.
class PolicyEngine {
  /// Creates a policy engine backed by [policyStore]. Tools without a stored
  /// policy are treated as [defaultPolicy] (default: [ToolPolicy.confirm]).
  PolicyEngine({
    required PolicyStore policyStore,
    this.defaultPolicy = ToolPolicy.confirm,
  }) : _policyStore = policyStore;

  final PolicyStore _policyStore;

  /// Policy applied to any tool that has no explicit entry in the store.
  final ToolPolicy defaultPolicy;

  /// Persists [policy] for [toolName]. Subsequent [getToolPolicy] /
  /// [decide] calls will see the new value.
  Future<void> setToolPolicy(String toolName, ToolPolicy policy) {
    return _policyStore.setToolPolicy(toolName, policy);
  }

  /// Returns the currently-effective policy for [toolName], falling back to
  /// [defaultPolicy].
  Future<ToolPolicy> getToolPolicy(String toolName) async {
    return await _policyStore.getToolPolicy(toolName) ?? defaultPolicy;
  }

  /// Resolves [toolName]'s policy and maps it to a runtime [PolicyDecision].
  Future<PolicyDecision> decide(String toolName) async {
    final policy = await getToolPolicy(toolName);
    return switch (policy) {
      ToolPolicy.auto => PolicyDecision.allow,
      ToolPolicy.confirm => PolicyDecision.requireConfirmation,
      ToolPolicy.deny => PolicyDecision.deny,
    };
  }
}
