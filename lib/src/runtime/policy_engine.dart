import 'grant_store.dart';
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

/// Source that produced a [PolicyDecision] — either the persistent
/// [PolicyStore] or an active [EphemeralGrant].
enum PolicySource {
  /// Decision came from the persistent [PolicyStore] (or [PolicyEngine.defaultPolicy]).
  stored,

  /// Decision came from an active [EphemeralGrant] and overrode the stored
  /// policy.
  grant,
}

/// Decision paired with the [PolicySource] that produced it. Callers that
/// need to know *why* a policy resolved a certain way (e.g. audit ledger,
/// UI chips) should use [PolicyEngine.decideDetailed] or
/// [PolicyEngine.peekDetailed].
class ResolvedPolicy {
  /// Creates a resolved-policy record.
  const ResolvedPolicy({
    required this.decision,
    required this.source,
    this.grant,
  });

  /// The runtime decision to act on.
  final PolicyDecision decision;

  /// Whether [decision] came from stored policy or an ephemeral grant.
  final PolicySource source;

  /// The grant that produced the decision, when [source] is
  /// [PolicySource.grant]. `null` otherwise.
  final EphemeralGrant? grant;
}

/// Resolves a [ToolPolicy] for each tool and maps it to a [PolicyDecision].
///
/// The engine reads policy from a [PolicyStore] (persistent or ephemeral) and
/// falls back to [defaultPolicy] when a tool has no stored policy yet. When a
/// [GrantStore] is supplied, an active [EphemeralGrant] overrides the stored
/// policy. Grants are consumed by [decide] / [decideDetailed] (actual
/// invocation); [peek] / [peekDetailed] inspect without consuming.
class PolicyEngine {
  /// Creates a policy engine backed by [policyStore]. Tools without a stored
  /// policy are treated as [defaultPolicy] (default: [ToolPolicy.confirm]).
  /// An optional [grantStore] enables ephemeral grants.
  PolicyEngine({
    required PolicyStore policyStore,
    GrantStore? grantStore,
    this.defaultPolicy = ToolPolicy.confirm,
  }) : _policyStore = policyStore,
       _grantStore = grantStore;

  final PolicyStore _policyStore;
  final GrantStore? _grantStore;

  /// Policy applied to any tool that has no explicit entry in the store.
  final ToolPolicy defaultPolicy;

  /// Persists [policy] for [toolName]. Subsequent [getToolPolicy] /
  /// [decide] calls will see the new value.
  Future<void> setToolPolicy(String toolName, ToolPolicy policy) {
    return _policyStore.setToolPolicy(toolName, policy);
  }

  /// Returns the currently-effective *persistent* policy for [toolName],
  /// falling back to [defaultPolicy]. Ignores any active grant — use
  /// [decide] / [peek] for the runtime-effective decision.
  Future<ToolPolicy> getToolPolicy(String toolName) async {
    return await _policyStore.getToolPolicy(toolName) ?? defaultPolicy;
  }

  /// Resolves [toolName] into a [PolicyDecision], consuming any active
  /// ephemeral grant along the way. Call this at actual invocation time.
  Future<PolicyDecision> decide(String toolName) async {
    return (await decideDetailed(toolName)).decision;
  }

  /// Like [decide], but also returns the [PolicySource] and the consumed
  /// [EphemeralGrant], if any.
  Future<ResolvedPolicy> decideDetailed(String toolName) =>
      _resolve(toolName, consumeGrant: true);

  /// Non-consuming counterpart to [decide]. Peeks at the current effective
  /// decision without decrementing grant use counts. Use from UI (policy
  /// chips, previews) where mutating state would be surprising.
  Future<PolicyDecision> peek(String toolName) async {
    return (await peekDetailed(toolName)).decision;
  }

  /// Non-consuming counterpart to [decideDetailed].
  Future<ResolvedPolicy> peekDetailed(String toolName) =>
      _resolve(toolName, consumeGrant: false);

  Future<ResolvedPolicy> _resolve(
    String toolName, {
    required bool consumeGrant,
  }) async {
    final grants = _grantStore;
    if (grants != null) {
      final grant = consumeGrant
          ? await grants.consume(toolName)
          : await grants.peek(toolName);
      if (grant != null) {
        return ResolvedPolicy(
          decision: _mapPolicy(grant.policy),
          source: PolicySource.grant,
          grant: grant,
        );
      }
    }
    final policy = await getToolPolicy(toolName);
    return ResolvedPolicy(
      decision: _mapPolicy(policy),
      source: PolicySource.stored,
    );
  }

  PolicyDecision _mapPolicy(ToolPolicy policy) {
    return switch (policy) {
      ToolPolicy.auto => PolicyDecision.allow,
      ToolPolicy.confirm => PolicyDecision.requireConfirmation,
      ToolPolicy.deny => PolicyDecision.deny,
    };
  }
}
