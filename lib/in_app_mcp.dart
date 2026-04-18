/// In-app MCP-style tool execution runtime for Flutter with policy
/// controls.
///
/// Exposes the [InAppMcp] facade plus the supporting model, policy, and
/// runtime types. See the project README for a walkthrough and the
/// `doc/` folder for architecture / API details.
library;

export 'src/model/preview.dart';
export 'src/model/tool_call.dart';
export 'src/model/tool_definition.dart';
export 'src/model/tool_error_code.dart';
export 'src/model/tool_result.dart';
export 'src/runtime/audit_ledger.dart';
export 'src/runtime/grant_store.dart';
export 'src/runtime/invocation_engine.dart';
export 'src/runtime/policy_engine.dart';
export 'src/runtime/policy_store.dart';
export 'src/runtime/tool_registry.dart';

import 'src/model/preview.dart';
import 'src/model/tool_call.dart';
import 'src/model/tool_definition.dart';
import 'src/model/tool_error_code.dart';
import 'src/model/tool_result.dart';
import 'src/runtime/audit_ledger.dart';
import 'src/runtime/grant_store.dart';
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
  ///
  /// Ephemeral grants are enabled by default with an [InMemoryGrantStore].
  /// Pass a custom [grantStore] to persist / observe grants, or set
  /// [enableGrants] to `false` to disable the grant layer entirely.
  ///
  /// The audit ledger is enabled by default with an [InMemoryAuditLedger].
  /// Pass a custom [auditLedger] to persist / observe entries, or set
  /// [enableAudit] to `false` to disable recording.
  factory InAppMcp({
    PolicyStore? policyStore,
    GrantStore? grantStore,
    bool enableGrants = true,
    AuditLedger? auditLedger,
    bool enableAudit = true,
    ToolPolicy defaultPolicy = ToolPolicy.confirm,
  }) {
    final grants = grantStore ?? (enableGrants ? InMemoryGrantStore() : null);
    final ledger = auditLedger ?? (enableAudit ? InMemoryAuditLedger() : null);
    return InAppMcp._(
      registry: ToolRegistry(),
      policyEngine: PolicyEngine(
        policyStore: policyStore ?? InMemoryPolicyStore(),
        grantStore: grants,
        defaultPolicy: defaultPolicy,
      ),
      invocationEngine: const InvocationEngine(),
      grantStore: grants,
      auditLedger: ledger,
    );
  }

  InAppMcp._({
    required ToolRegistry registry,
    required PolicyEngine policyEngine,
    required InvocationEngine invocationEngine,
    required GrantStore? grantStore,
    required AuditLedger? auditLedger,
  }) : _registry = registry,
       _policyEngine = policyEngine,
       _invocationEngine = invocationEngine,
       _grantStore = grantStore,
       _auditLedger = auditLedger;

  final ToolRegistry _registry;
  final PolicyEngine _policyEngine;
  final InvocationEngine _invocationEngine;
  final AuditLedger? _auditLedger;
  final GrantStore? _grantStore;

  /// The backing audit ledger, or `null` when the ledger is disabled.
  AuditLedger? get auditLedger => _auditLedger;

  /// Closes long-lived resources (audit ledger stream controller, grant
  /// store). Idempotent. Call from your app's teardown if you create more
  /// than one [InAppMcp] instance over the process lifetime.
  Future<void> dispose() async {
    final ledger = _auditLedger;
    if (ledger is InMemoryAuditLedger) await ledger.close();
  }

  /// Registers [handler] as the implementation for [definition].
  ///
  /// Re-registering under the same [ToolDefinition.name] replaces the prior
  /// entry.
  ///
  /// - [previewer] is an optional pure function returning a [Preview] of what
  ///   [handler] *would* do. Surface it to the user before showing the
  ///   confirmation card — it catches LLM mistakes early.
  /// - [undoer] is an optional reverse-effect handler. When present,
  ///   [undoFromLedger] can revert a previously-executed call.
  void registerTool({
    required ToolDefinition definition,
    required ToolHandler handler,
    ToolPreviewer? previewer,
    ToolUndoer? undoer,
  }) {
    _registry.registerTool(
      definition: definition,
      handler: handler,
      previewer: previewer,
      undoer: undoer,
    );
  }

  /// Runs the registered previewer for [call] (if any) without executing the
  /// handler. Returns `null` when the tool has no previewer or no matching
  /// registration. Never touches policy or grants.
  Future<Preview?> previewToolCall(ToolCall call) async {
    final tool = _registry.find(call.toolName);
    final previewer = tool?.previewer;
    if (previewer == null) return null;
    return previewer(call);
  }

  /// Fixed-length snapshot of every currently-registered [ToolDefinition].
  List<ToolDefinition> get tools => _registry.listTools();

  /// Returns `{"tools": [...]}` where each entry is the JSON schema from
  /// [ToolDefinition.toJsonSchema]. Useful for feeding the full tool
  /// catalog to an LLM adapter in a single call.
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
  /// whose policy is [ToolPolicy.confirm]. An active [EphemeralGrant]
  /// whose policy is [ToolPolicy.auto] substitutes for `confirmed` and is
  /// consumed by this call.
  Future<ToolResult> handleToolCall(ToolCall call, {bool confirmed = false}) {
    return _invocationEngine.handle(
      call: call,
      registry: _registry,
      policyEngine: _policyEngine,
      confirmed: confirmed,
      auditLedger: _auditLedger,
    );
  }

  /// Persists [policy] for [toolName] in the backing [PolicyStore].
  Future<void> setToolPolicy(String toolName, ToolPolicy policy) {
    return _policyEngine.setToolPolicy(toolName, policy);
  }

  /// Reads the effective persistent [ToolPolicy] for [toolName], falling
  /// back to the runtime's `defaultPolicy`. Ignores ephemeral grants — use
  /// [getPolicyDecision] for the runtime-effective decision.
  Future<ToolPolicy> getToolPolicy(String toolName) {
    return _policyEngine.getToolPolicy(toolName);
  }

  /// Non-consuming peek at [toolName]'s current runtime decision, accounting
  /// for any active [EphemeralGrant]. Safe to call from UI.
  Future<PolicyDecision> getPolicyDecision(String toolName) {
    return _policyEngine.peek(toolName);
  }

  /// Like [getPolicyDecision] but also returns the [PolicySource] and the
  /// backing [EphemeralGrant], if any.
  Future<ResolvedPolicy> getResolvedPolicy(String toolName) {
    return _policyEngine.peekDetailed(toolName);
  }

  /// Grants [toolName] the [EphemeralGrant.once] pattern — one invocation
  /// under [policy] (default [ToolPolicy.auto]), then the grant is revoked.
  Future<void> grantOnce(
    String toolName, {
    ToolPolicy policy = ToolPolicy.auto,
  }) {
    return _requireGrantStore().put(
      EphemeralGrant.once(toolName, policy: policy),
    );
  }

  /// Grants [toolName] the [EphemeralGrant.forDuration] pattern — unlimited
  /// invocations under [policy] until [duration] elapses.
  Future<void> grantFor(
    String toolName,
    Duration duration, {
    ToolPolicy policy = ToolPolicy.auto,
  }) {
    return _requireGrantStore().put(
      EphemeralGrant.forDuration(toolName, duration, policy: policy),
    );
  }

  /// Grants [toolName] the [EphemeralGrant.untilCleared] pattern — no
  /// expiry, no use limit, stays active until revoked. Use for
  /// "allow for this session" semantics where the host app controls session
  /// lifetime.
  Future<void> grantUntilCleared(
    String toolName, {
    ToolPolicy policy = ToolPolicy.auto,
  }) {
    return _requireGrantStore().put(
      EphemeralGrant.untilCleared(toolName, policy: policy),
    );
  }

  /// Revokes any active grant for [toolName].
  Future<void> revokeGrant(String toolName) {
    return _requireGrantStore().revoke(toolName);
  }

  /// Revokes every active grant. Typically called when a "session" ends
  /// (e.g. user leaves a chat, logs out).
  Future<void> revokeAllGrants() {
    return _requireGrantStore().revokeAll();
  }

  /// Snapshot of every currently-active grant.
  Future<List<EphemeralGrant>> listActiveGrants() {
    return _requireGrantStore().listActive();
  }

  /// Current grant for [toolName] without consuming it, or `null` if none.
  Future<EphemeralGrant?> peekGrant(String toolName) {
    return _requireGrantStore().peek(toolName);
  }

  /// Reverts a previously-executed tool call identified by [auditEntryId].
  ///
  /// Steps:
  /// 1. Fetch the [AuditEntry] from the ledger; fail with `entry_not_found`
  ///    if missing.
  /// 2. Require that the entry's result succeeded; nothing to undo otherwise.
  /// 3. Locate the tool's registered [ToolUndoer]; fail with `undo_not_supported`
  ///    if absent.
  /// 4. Run the undoer with the original [ToolCall] and [ToolResult].
  /// 5. Mark the ledger entry undone with the undoer's result.
  ///
  /// Returns the undoer's [ToolResult] (or a failure describing the
  /// short-circuit). The original entry is never mutated beyond setting the
  /// `undone` / `undoneAt` / `undoResult` fields.
  Future<ToolResult> undoFromLedger(String auditEntryId) async {
    final ledger = _auditLedger;
    if (ledger == null) {
      return ToolResult.fail(
        ToolErrorCode.auditDisabled,
        'Audit ledger is disabled — nothing to undo from.',
      );
    }

    final entry = await ledger.get(auditEntryId);
    if (entry == null) {
      return ToolResult.fail(
        ToolErrorCode.entryNotFound,
        'Audit entry $auditEntryId not found.',
      );
    }
    if (entry.undone) {
      return ToolResult.fail(
        ToolErrorCode.alreadyUndone,
        'Audit entry $auditEntryId is already undone.',
      );
    }
    if (!entry.result.success) {
      return ToolResult.fail(
        ToolErrorCode.nothingToUndo,
        'Audit entry $auditEntryId did not succeed; nothing to undo.',
      );
    }

    final tool = _registry.find(entry.call.toolName);
    final undoer = tool?.undoer;
    if (undoer == null) {
      return ToolResult.fail(
        ToolErrorCode.undoNotSupported,
        'Tool ${entry.call.toolName} does not support undo.',
      );
    }

    final undoResult = await undoer(entry.call, entry.result);
    if (undoResult.success) {
      await ledger.markUndone(entry.id, undoResult: undoResult);
    }
    return undoResult;
  }

  GrantStore _requireGrantStore() {
    final store = _grantStore;
    if (store == null) {
      throw StateError(
        'Ephemeral grants are disabled for this InAppMcp instance '
        '(constructed with enableGrants: false). Pass a GrantStore or enable '
        'grants to use this API.',
      );
    }
    return store;
  }
}
