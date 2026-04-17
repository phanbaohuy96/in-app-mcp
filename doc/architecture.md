# Architecture

## Overview

`in_app_mcp` is structured as a small runtime core with explicit boundaries:

- **Model layer**: typed request/result contracts
- **Policy layer**: per-tool authorization decisions
- **Registry layer**: tool registration + argument validation
- **Invocation layer**: execution orchestration

## Layers

### 1) Model (`lib/src/model`)

- `ToolCall`
  - incoming tool invocation payload
  - fields: `id`, `toolName`, `arguments`, optional `requestId`
- `ToolDefinition`
  - tool schema metadata and validator
- `ToolResult`
  - normalized execution result
- `ToolErrorCode`
  - shared runtime error code constants

### 2) Policy (`lib/src/runtime/policy_*`)

- `ToolPolicy`
  - `auto`, `confirm`, `deny`
- `PolicyDecision`
  - runtime decision: `allow`, `requireConfirmation`, `deny`
- `PolicyStore`
  - abstraction for policy persistence
- `InMemoryPolicyStore`
  - default ephemeral implementation
- `PolicyEngine`
  - resolves policy per tool and maps to decision

### 3) Registry (`lib/src/runtime/tool_registry.dart`)

- holds `Map<String, RegisteredTool>`
- registers `ToolDefinition + ToolHandler`
- validates arguments via tool definition
- invokes handler

### 4) Invocation (`lib/src/runtime/invocation_engine.dart`)

Execution order:
1. Resolve registered tool.
2. Evaluate policy decision.
3. Enforce confirmation gate.
4. Delegate validation + execution to registry.

## Entry point (`lib/in_app_mcp.dart`)

`InAppMcp` composes:
- `ToolRegistry`
- `PolicyEngine`
- `InvocationEngine`

And exposes:
- `registerTool`
- `handleToolCall`
- `setToolPolicy`
- `getToolPolicy`
- `getPolicyDecision`

## Example architecture (`example/`)

- `llm/`
  - `LlmAdapter` interface
  - `MockLlmAdapter` implementation producing `ToolCall`
- `agent_tools/`
  - `ToolCatalog` registration
  - `ScheduleWeekdayAlarmTool` side-effect handler
- `screens/`
  - policy settings UI
  - chat demo + confirmation dialog

## Design choices

- **Provider-neutral core**: no direct LLM SDK dependency.
- **Policy-first execution**: decision before side effects.
- **Typed boundaries**: adapter returns `ToolCall`, not untyped maps.
- **Centralized error codes**: stable machine-readable outcomes.

## Known constraints

- Mobile OS permissions still require user consent at first use.
- Exact timing guarantees depend on platform behavior.
- MVP policy storage is in-memory only.

## Recommended extension points

1. Implement custom `PolicyStore` for persistence.
2. Add richer validators on top of `ToolDefinition`.
3. Add domain tool packages that register through `InAppMcp`.
