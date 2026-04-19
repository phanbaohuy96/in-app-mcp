import '../model/tool_call.dart';
import '../model/tool_result.dart';
import 'audit_ledger.dart';
import 'policy_engine.dart';

/// Pluggable hook into the `InvocationEngine.handle` pipeline.
///
/// Interceptors let host apps observe or modify parts of the pipeline
/// without implementing a whole [PolicyStore] / [GrantStore] / [AuditLedger].
/// Typical use cases:
///
/// - remote / tenant-aware policy overrides → [onResolvePolicy]
/// - rate limiting / feature-flag denials → [beforeExecute]
/// - PII redaction / response shaping → [afterExecute]
/// - telemetry fan-out to Sentry / Datadog / local file → [onAudit]
///
/// All methods are optional. The default implementations pass through
/// unchanged.
///
/// ## Chain semantics
///
/// Interceptors run in the order they were passed to `InAppMcp`.
///
/// - [onResolvePolicy] and [afterExecute] are *chain-through*: each
///   interceptor sees the upstream value (as possibly modified by earlier
///   interceptors) and either returns `null` (pass) or a new value that
///   becomes the input to the next interceptor.
/// - [beforeExecute] is *first-wins*: the first interceptor to return a
///   non-null [ToolResult] short-circuits the rest. Use this to veto a call
///   (rate limit, quota exceeded, tenant unauthorised).
/// - [onAudit] is *fan-out*: every registered interceptor is notified, and
///   exceptions thrown from it are swallowed so telemetry failures never
///   break the actual tool invocation.
///
/// Exceptions from the *modifying* hooks ([onResolvePolicy],
/// [beforeExecute], [afterExecute]) propagate up and fail the invocation
/// just as a handler exception would. Only [onAudit] swallows errors.
abstract class InvocationInterceptor {
  /// Base constructor for subclasses — `InvocationInterceptor` has no
  /// state of its own.
  const InvocationInterceptor();

  /// Inspect or replace the resolved policy for [toolName].
  ///
  /// Fired after the [PolicyEngine] has consumed any active
  /// [EphemeralGrant] and before the decision gate runs. Return `null` to
  /// accept [upstream]; return a new [ResolvedPolicy] to override it.
  Future<ResolvedPolicy?> onResolvePolicy(
    String toolName,
    ResolvedPolicy upstream,
  ) async => null;

  /// Veto a pending invocation.
  ///
  /// Fired after policy has allowed the call and before the handler runs.
  /// Return `null` to proceed with execution; return a failure
  /// [ToolResult] (typically `ToolResult.fail(code, message)`) to
  /// short-circuit the invocation without running the handler.
  Future<ToolResult?> beforeExecute(
    ToolCall call,
    ResolvedPolicy resolved,
  ) async => null;

  /// Rewrite the handler's [result] before it's recorded and returned.
  ///
  /// Return `null` to keep [result]; return a new [ToolResult] to replace
  /// it. Subsequent interceptors in the chain see the replacement.
  Future<ToolResult?> afterExecute(ToolCall call, ToolResult result) async =>
      null;

  /// Observe every recorded [AuditEntry].
  ///
  /// Fire-and-forget: exceptions are swallowed so telemetry failures
  /// cannot break the invocation. Use this for analytics forwarding, log
  /// shipping, or crash-reporter breadcrumbs.
  ///
  /// Compared to listening on [AuditLedger.changes]: `onAudit` is awaited
  /// *inline* with the invocation (so the tool call doesn't complete until
  /// every interceptor has had a chance to run), while `changes` stream
  /// events fire asynchronously after the call returns. Pick `onAudit`
  /// when you need deterministic ordering relative to the caller (e.g.
  /// tests, synchronous breadcrumb flush); pick `changes` when you want a
  /// long-lived observer that's decoupled from invocation latency.
  Future<void> onAudit(AuditEntry entry) async {}
}
