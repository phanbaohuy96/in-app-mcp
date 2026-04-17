import 'policy_store.dart';

enum ToolPolicy {
  auto,
  confirm,
  deny,
}

enum PolicyDecision {
  allow,
  requireConfirmation,
  deny,
}

class PolicyEngine {
  PolicyEngine({
    required PolicyStore policyStore,
    this.defaultPolicy = ToolPolicy.confirm,
  }) : _policyStore = policyStore;

  final PolicyStore _policyStore;
  final ToolPolicy defaultPolicy;

  Future<void> setToolPolicy(String toolName, ToolPolicy policy) {
    return _policyStore.setToolPolicy(toolName, policy);
  }

  Future<ToolPolicy> getToolPolicy(String toolName) async {
    return await _policyStore.getToolPolicy(toolName) ?? defaultPolicy;
  }

  Future<PolicyDecision> decide(String toolName) async {
    final policy = await getToolPolicy(toolName);
    return switch (policy) {
      ToolPolicy.auto => PolicyDecision.allow,
      ToolPolicy.confirm => PolicyDecision.requireConfirmation,
      ToolPolicy.deny => PolicyDecision.deny,
    };
  }
}
