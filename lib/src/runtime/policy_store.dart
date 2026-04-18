import 'policy_engine.dart';

/// Abstract store for per-tool [ToolPolicy] values.
///
/// Implementations decide how policy is persisted — e.g. in memory,
/// `SharedPreferences`, a secure keystore, or a backing database. The
/// runtime-default implementation is [InMemoryPolicyStore].
abstract class PolicyStore {
  /// Base constructor for subclasses — `PolicyStore` has no state of its own.
  const PolicyStore();

  /// Writes [policy] for [toolName]. Overwrites any prior value.
  Future<void> setToolPolicy(String toolName, ToolPolicy policy);

  /// Reads the stored policy for [toolName], or `null` if none has been set.
  Future<ToolPolicy?> getToolPolicy(String toolName);
}

/// Ephemeral [PolicyStore] backed by a process-local map. Values do not
/// survive a restart.
class InMemoryPolicyStore implements PolicyStore {
  /// Creates an empty in-memory store.
  InMemoryPolicyStore();

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
