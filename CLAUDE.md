# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Scope

`in_app_mcp` is a Flutter plugin package that provides a runtime for in-app LLM/agent tool execution with policy controls.

Core intent:
- keep the runtime provider-neutral
- validate tool calls before side effects
- enforce per-tool policy (`auto`, `confirm`, `deny`)
- return structured, machine-readable outcomes

## Common Commands

Run from repository root unless noted.

### Install dependencies
```bash
flutter pub get
```

### Analyze and test (package)
```bash
flutter analyze
flutter test test
```

### Run a single package test file
```bash
flutter test test/in_app_mcp_test.dart
```

### Run a single test by name
```bash
flutter test test/in_app_mcp_test.dart --plain-name "executes when confirmed"
```

### Example app workflow
```bash
cd example
flutter pub get
flutter analyze
flutter test
flutter run
```

### Run a single example test file
```bash
cd example
flutter test test/widget_test.dart
flutter test integration_test/plugin_integration_test.dart
```

## High-Level Architecture

The package is intentionally split into runtime layers in `lib/src`:

- **Model layer** (`lib/src/model`)
  - `ToolCall`, `ToolDefinition`, `ToolResult`, `ToolErrorCode`
  - `ToolDefinition.validateArguments` handles top-level argument contract checks.

- **Policy layer** (`lib/src/runtime/policy_engine.dart`, `policy_store.dart`)
  - `PolicyEngine` converts `ToolPolicy` to runtime `PolicyDecision`.
  - `PolicyStore` abstraction allows future persistence; current default is `InMemoryPolicyStore`.

- **Registry layer** (`lib/src/runtime/tool_registry.dart`)
  - Registers tool definitions + handlers.
  - Owns validation and invocation (`invoke`, `invokeRegistered`).

- **Invocation layer** (`lib/src/runtime/invocation_engine.dart`)
  - Orchestrates execution order: resolve tool → policy gate → registry invocation.
  - Confirmation gate is enforced here via `confirmed`.

- **Facade** (`lib/in_app_mcp.dart`)
  - `InAppMcp` composes registry/policy/invocation and exposes the public API used by apps.

## Example App Structure (reference implementation)

`example/` demonstrates the intended integration pattern:

- `lib/llm/`
  - `LlmAdapter` boundary returns typed `ToolCall`.
  - `MockLlmAdapter` provides deterministic demo calls.

- `lib/agent_tools/`
  - `ToolCatalog` registers tools into `InAppMcp`.
  - `ScheduleWeekdayAlarmTool` is the current side-effect example (notifications).

- `lib/screens/`
  - `SettingsPolicyScreen` manages per-tool policy.
  - `ChatDemoScreen` drives prompt → tool call → optional confirmation → execution.

## Implementation Notes for Future Changes

- Keep provider-specific LLM SDK logic out of core runtime; put adapters in example or separate packages.
- Reuse `ToolErrorCode` constants for runtime errors instead of hardcoded strings.
- Keep policy evaluation before side effects.
- If adding new tools, register through `ToolCatalog` in example and include corresponding tests.
- `ToolDefinition` currently validates only top-level argument types; stricter nested validation should be added explicitly in handlers or by extending schema support.

## Source of Truth Docs

For deeper details, prefer these documents:
- `README.md`
- `doc/architecture.md`
- `doc/api.md`
- `doc/example_workflow.md`
