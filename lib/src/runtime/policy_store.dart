import 'policy_engine.dart';

abstract class PolicyStore {
  Future<void> setToolPolicy(String toolName, ToolPolicy policy);
  Future<ToolPolicy?> getToolPolicy(String toolName);
}

class InMemoryPolicyStore implements PolicyStore {
  final Map<String, ToolPolicy> _policies = {};

  @override
  Future<ToolPolicy?> getToolPolicy(String toolName) async {
    return _policies[toolName];
  }

  @override
  Future<void> setToolPolicy(String toolName, ToolPolicy policy) async {
    _policies[toolName] = policy;
  }
}
