import 'policy_engine.dart';

/// A time- or use-bounded override on top of a tool's stored [ToolPolicy].
///
/// Grants are the "allow once / allow for N minutes / allow for this session"
/// primitive. They are consulted by [PolicyEngine] before the persistent
/// [PolicyStore], so a user can temporarily upgrade a `confirm`/`deny` tool
/// to `auto` without mutating their durable settings.
///
/// Construct via [EphemeralGrant.once], [EphemeralGrant.forDuration], or
/// [EphemeralGrant.untilCleared].
class EphemeralGrant {
  /// Creates a grant directly. Prefer the named constructors.
  EphemeralGrant({
    required this.toolName,
    required this.policy,
    this.expiresAt,
    this.remainingUses,
  });

  /// Grant valid for exactly one invocation, then auto-revoked.
  factory EphemeralGrant.once(
    String toolName, {
    ToolPolicy policy = ToolPolicy.auto,
  }) {
    return EphemeralGrant(toolName: toolName, policy: policy, remainingUses: 1);
  }

  /// Grant valid until [DateTime.now] + [duration]; unlimited uses within.
  factory EphemeralGrant.forDuration(
    String toolName,
    Duration duration, {
    ToolPolicy policy = ToolPolicy.auto,
    DateTime? now,
  }) {
    return EphemeralGrant(
      toolName: toolName,
      policy: policy,
      expiresAt: (now ?? DateTime.now()).add(duration),
    );
  }

  /// Grant valid until explicitly revoked; unlimited uses and no expiry.
  /// Use this for "allow for this session" semantics — the host app decides
  /// when the session ends and calls `revokeGrant` / `revokeAllGrants`.
  factory EphemeralGrant.untilCleared(
    String toolName, {
    ToolPolicy policy = ToolPolicy.auto,
  }) {
    return EphemeralGrant(toolName: toolName, policy: policy);
  }

  /// Tool this grant applies to.
  final String toolName;

  /// Policy to apply while this grant is active (typically [ToolPolicy.auto]).
  final ToolPolicy policy;

  /// When this grant stops being valid. `null` means no time limit.
  final DateTime? expiresAt;

  /// Remaining number of invocations allowed. `null` means unlimited.
  final int? remainingUses;

  /// `true` if [expiresAt] is in the past.
  bool isExpired({DateTime? now}) {
    final expiry = expiresAt;
    if (expiry == null) return false;
    return !(now ?? DateTime.now()).isBefore(expiry);
  }

  /// `true` if [remainingUses] has been decremented to zero.
  bool get isExhausted => remainingUses != null && remainingUses! <= 0;

  /// `true` if the grant is currently usable.
  bool isActive({DateTime? now}) => !isExpired(now: now) && !isExhausted;

  /// Returns a copy with [remainingUses] decremented by one (floored at 0).
  /// No-op when [remainingUses] is `null`.
  EphemeralGrant decrement() {
    final uses = remainingUses;
    if (uses == null) return this;
    return EphemeralGrant(
      toolName: toolName,
      policy: policy,
      expiresAt: expiresAt,
      remainingUses: uses > 0 ? uses - 1 : 0,
    );
  }
}

/// Storage for currently-active [EphemeralGrant]s.
///
/// Typical implementations are in-memory and process-local ([InMemoryGrantStore]);
/// there is usually no reason to persist grants across restarts — their whole
/// point is to be ephemeral.
abstract class GrantStore {
  /// Base constructor for subclasses — `GrantStore` has no state of its own.
  const GrantStore();

  /// Stores [grant], replacing any previous grant for the same tool.
  Future<void> put(EphemeralGrant grant);

  /// Removes any grant for [toolName]. No-op if none exists.
  Future<void> revoke(String toolName);

  /// Removes every grant in the store.
  Future<void> revokeAll();

  /// Returns the current grant for [toolName] without mutating it. Callers
  /// should treat an expired or exhausted grant as absent — [PolicyEngine]
  /// does this automatically.
  Future<EphemeralGrant?> peek(String toolName);

  /// Returns the current active grant for [toolName] and decrements its
  /// [EphemeralGrant.remainingUses] by one. Grants that reach zero remaining
  /// uses or are already expired are revoked.
  ///
  /// Returns `null` if no active grant exists.
  Future<EphemeralGrant?> consume(String toolName);

  /// Snapshot of every currently-active grant.
  Future<List<EphemeralGrant>> listActive();
}

/// Default [GrantStore] backed by a process-local map.
class InMemoryGrantStore implements GrantStore {
  /// Creates an empty store.
  InMemoryGrantStore();

  final Map<String, EphemeralGrant> _grants = {};

  @override
  Future<void> put(EphemeralGrant grant) async {
    _grants[grant.toolName] = grant;
  }

  @override
  Future<void> revoke(String toolName) async {
    _grants.remove(toolName);
  }

  @override
  Future<void> revokeAll() async {
    _grants.clear();
  }

  @override
  Future<EphemeralGrant?> peek(String toolName) async {
    final grant = _grants[toolName];
    if (grant == null) return null;
    if (!grant.isActive()) {
      _grants.remove(toolName);
      return null;
    }
    return grant;
  }

  @override
  Future<EphemeralGrant?> consume(String toolName) async {
    final grant = _grants[toolName];
    if (grant == null || !grant.isActive()) {
      if (grant != null) _grants.remove(toolName);
      return null;
    }
    final next = grant.decrement();
    if (next.isActive()) {
      _grants[toolName] = next;
    } else {
      _grants.remove(toolName);
    }
    return grant;
  }

  @override
  Future<List<EphemeralGrant>> listActive() async {
    _grants.removeWhere((_, g) => !g.isActive());
    return List.unmodifiable(_grants.values);
  }
}
