## 1.1.0

**Consent Lifecycle** — four composable features that turn `in_app_mcp` from a policy gate into a full preview → confirm → execute → audit → undo trust loop for in-app AI tool calls.

### Added
- **Ephemeral grants** (`EphemeralGrant` + `GrantStore` + `InMemoryGrantStore`). One-use, time-bounded, or session-scoped policy upgrades. New facade methods: `grantOnce` / `grantFor` / `grantUntilCleared` / `revokeGrant` / `revokeAllGrants` / `listActiveGrants` / `peekGrant`.
- **Audit ledger** (`AuditLedger` + `AuditEntry` + `InMemoryAuditLedger`). Every call outcome (successes, policy denials, confirmation short-circuits, missing tools) records one entry. `changes` stream for live UI. Exposed via `InAppMcp.auditLedger`.
- **Preview hook** (`Preview` + `PreviewWarning` + `ToolPreviewer` typedef). Side-effect-free function registered alongside a tool's handler; runtime exposes `InAppMcp.previewToolCall`. New `@McpToolPreview` annotation + generator support in `in_app_mcp_gen`.
- **Undo hook** (`ToolUndoer` typedef + `InAppMcp.undoFromLedger`). Reverses a prior successful call by running the tool's registered undoer and marking the ledger entry undone. New `@McpToolUndo` annotation + generator support. Five new `ToolErrorCode`s: `auditDisabled`, `entryNotFound`, `alreadyUndone`, `nothingToUndo`, `undoNotSupported`.
- **PolicyEngine** gained `peek` / `peekDetailed` (non-consuming), `decideDetailed`, `ResolvedPolicy`, `PolicySource`.
- `InAppMcp.dispose()` for ledger teardown.

### Example app
- Inline tool-call card now shows a preview section with warnings, a grant submenu ("Run + allow 5 min / for session"), and a per-entry Undo button after success.
- New **audit timeline** screen browses ledger history with per-entry undo.
- New **Active grants** card in settings with individual + revoke-all controls.
- `ScheduleWeekdayAlarmTool` ships a previewer ("Would schedule X at HH:MM on Mon, Tue, …") and an undoer (cancels the notifications).
- New E2E integration test `example/integration_test/consent_lifecycle_test.dart` covers preview → grant → execute → audit → undo.

### Changed
- `ToolRegistry.registerTool` accepts optional `previewer` / `undoer`.
- `InvocationEngine.handle` records every outcome to an optional `auditLedger` including pre-policy and pre-execution short-circuits.
- `InAppMcp` constructor adds optional `grantStore`, `auditLedger`, `enableGrants`, `enableAudit` with in-memory defaults; `getPolicyDecision` now peeks (non-consuming).

All changes are additive — existing consumers of 1.0.x keep working unchanged.

## 1.0.2

- Reposition README and pub.dev description around the per-tool policy gate (the differentiator vs. `mcp_server` / `mcp_client` / `dart_agent_core`). No runtime changes.
- Clarify in README that `in_app_mcp` is a local in-process tool runtime, not an implementation of the MCP wire protocol (JSON-RPC / stdio / SSE).
- Refresh the "Current status" section to reflect the 5 demo tools and codegen companions shipped alongside the 1.0.x runtime.
- Add dartdoc to the remaining default constructors (`PolicyStore`, `InMemoryPolicyStore`, `ToolErrorCode`, `ToolRegistry`) — pana dartdoc coverage rises from 94.8% to 100%.

## 1.0.1

- Convert `in_app_mcp` from a Flutter plugin to a pure Flutter package. The plugin scaffolding from `flutter create --template=plugin` (`android/`, `ios/`, `lib/in_app_mcp_method_channel.dart`, `lib/in_app_mcp_platform_interface.dart`) was unused — `lib/in_app_mcp.dart` never called into it. The package now supports every platform Flutter targets out of the box.
- Drop unused `plugin_platform_interface` dependency.
- Add dartdoc comments across the public API (`InAppMcp`, `ToolCall`, `ToolDefinition`, `ToolArgType`, `ToolResult`, `ToolErrorCode`, `ToolPolicy`, `PolicyDecision`, `PolicyStore`, `InMemoryPolicyStore`, `ToolRegistry`, `RegisteredTool`, `InvocationEngine`). No behavioural changes.

## 1.0.0

- Stable public API.
- Add `ToolDefinition.toJsonSchema()` returning an OpenAI-style JSON schema so LLM adapters can serialise a tool definition without hand-rolling it.
- Add `InAppMcp.toolsSchemaJson()` aggregating schemas for every registered tool into `{"tools": [...]}`.
- Redesign the example app's inline tool-call card with per-tool icons, colour-coded status and policy chips, and a structured result view instead of raw JSON.
- Fix `gemma_adapter` handling of responses where Gemma 4 E2B emits unquoted JSON object keys (e.g. `{"toolName":"x","arguments":{hour:6}}`). A preprocessing pass quotes bareword keys before `ToolCallParser` runs.
- Ship companion packages `in_app_mcp_annotations` and `in_app_mcp_gen` for generating `ToolDefinition`s and typed handler adapters from annotated Dart functions.

## 0.0.2

- Expand example app with a full-screen chat experience and dedicated settings screen.
- Add inline tool-call proposal cards with manual Run/Cancel and per-tool policy visibility.
- Add Gemma adapter flow with model selection, local model catalog/status management, and tool-call parsing helpers.
- Add additional example tools (calendar, maps, email) and broaden integration/widget/parser test coverage.
- Improve runtime validation and policy/registry behavior for stricter tool argument handling.

## 0.0.1

- Initial release of `in_app_mcp` with in-app tool runtime, policy controls, registry, and method-channel scaffolding.
