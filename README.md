# in_app_mcp

`in_app_mcp` is a Flutter package for executing **in-app agent tool calls** with policy controls.

It is designed as the runtime layer between an LLM/chat agent and your app capabilities:
- register tools
- validate arguments
- enforce user policy (`auto`, `confirm`, `deny`)
- execute handlers and return structured results

The current MVP includes a complete runtime API and an example app that demonstrates scheduling weekday alarms through a tool call flow.

## Why this package

Most Flutter AI packages focus on prompting and model orchestration. Most scheduling packages focus on notifications/alarms only.

`in_app_mcp` focuses on the execution boundary:
- typed tool contracts
- runtime validation
- policy/consent enforcement
- predictable result/error payloads

## Current status

MVP runtime is implemented.

What exists today:
- core tool runtime in `lib/src/**`
- in-memory policy store
- centralized error codes
- example app with:
  - policy settings UI
  - mock LLM adapter
  - one tool: `schedule_weekday_alarm`

What is intentionally not in core yet:
- provider-specific LLM SDK coupling
- persistent policy store implementation
- broad native capability catalog

## Installation

Add dependency:

```yaml
dependencies:
  in_app_mcp: ^0.0.1
```

Then run:

```bash
flutter pub get
```

## Quick start

```dart
import 'package:in_app_mcp/in_app_mcp.dart';

final mcp = InAppMcp(defaultPolicy: ToolPolicy.confirm);

mcp.registerTool(
  definition: const ToolDefinition(
    name: 'echo',
    description: 'Echo message back',
    argumentTypes: {
      'message': ToolArgType.string,
    },
    requiredArguments: {'message'},
    allowAdditionalArguments: false,
  ),
  handler: (call) async {
    return ToolResult.ok('ok', data: {'echo': call.arguments['message']});
  },
);

final call = ToolCall(
  id: '1',
  toolName: 'echo',
  arguments: {'message': 'hello'},
);

final result = await mcp.handleToolCall(call, confirmed: true);
print(result.toJson());
```

## Runtime flow

1. LLM adapter produces `ToolCall`
2. `InAppMcp` resolves policy for `toolName`
3. If denied → `policy_denied`
4. If confirmation required and not confirmed → `confirmation_required`
5. Registry validates arguments
6. Handler executes and returns `ToolResult`

## Public API surface

### Models
- `ToolCall`
- `ToolDefinition`
- `ToolArgType`
- `ToolResult`
- `ToolErrorCode`

### Runtime
- `InAppMcp`
- `ToolPolicy`
- `PolicyDecision`
- `PolicyStore`
- `InMemoryPolicyStore`
- `ToolRegistry`
- `InvocationEngine`

## Error codes

`ToolErrorCode` currently includes:
- `tool_not_found`
- `invalid_arguments`
- `policy_denied`
- `confirmation_required`

## Example app

The example app lives under `example/` and demonstrates:
- user policy selection (`Auto`, `Confirm`, `Deny`)
- mock user prompt → mock tool call
- optional confirmation dialog when policy is `confirm`
- scheduling a weekday alarm notification tool

Run it:

```bash
cd example
flutter pub get
flutter run
```

## Testing

From package root:

```bash
flutter analyze
flutter test test
```

Example app checks:

```bash
cd example
flutter analyze
flutter test
```

## Security notes

- Do not hardcode API keys in source.
- Treat tool handlers as side-effect boundaries; validate external inputs.
- Keep risky tools behind `confirm` or `deny` by default.
- OS-level permission prompts are still required where platform policies demand them.

## Roadmap

Planned next steps:
- persistent policy store (e.g. SharedPreferences-backed)
- richer argument schema/validators (e.g. `array<int>` semantics in core)
- optional provider adapters (Grok/OpenAI/etc.) in example or side packages
- federated capability plugins for reminders/calendar/contacts
- audit/event hooks for observability

## Documentation

See:
- `docs/architecture.md`
- `docs/api.md`
- `docs/example_workflow.md`
