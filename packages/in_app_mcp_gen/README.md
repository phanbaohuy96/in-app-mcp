# in_app_mcp_gen

Build-runner code generator for [`in_app_mcp`](https://pub.dev/packages/in_app_mcp). Produces a `ToolDefinition` and a typed handler adapter for every `@McpTool`-annotated top-level function.

## Setup

```yaml
dependencies:
  in_app_mcp: ^0.0.2
  in_app_mcp_annotations: ^0.0.1

dev_dependencies:
  build_runner: ^2.4.0
  in_app_mcp_gen: ^0.0.1
```

## Usage

```dart
import 'package:in_app_mcp/in_app_mcp.dart';
import 'package:in_app_mcp_annotations/in_app_mcp_annotations.dart';

part 'my_tools.mcp.g.dart';

@McpTool(description: 'Echo a message back.')
Future<ToolResult> echo({required String message}) async {
  return ToolResult.ok('ok', data: {'echo': message});
}
```

Run:

```bash
dart run build_runner build
```

The generator emits `my_tools.mcp.g.dart` next to the source file, containing:

```dart
const ToolDefinition echoDefinition = ToolDefinition(
  name: 'echo',
  description: 'Echo a message back.',
  argumentTypes: {'message': ToolArgType.string},
  requiredArguments: {'message'},
  allowAdditionalArguments: false,
);

Future<ToolResult> echoHandler(ToolCall call) {
  return echo(message: call.arguments['message'] as String);
}
```

Register it with the runtime:

```dart
final mcp = InAppMcp();
mcp.registerTool(definition: echoDefinition, handler: echoHandler);
```

## Supported parameter types

- `String`, `int`, `double`, `num`, `bool`
- `List<T>` — casts to `List<T>` at runtime
- `Map<K, V>` — casts to `Map<K, V>` at runtime
- Nullable variants of any of the above

Parameters must be named. Positional parameters are rejected at generation time.

## Limitations (0.0.1)

- Only top-level functions are supported (not methods on classes).
- The function must return `Future<ToolResult>`.
- No nested validation (`@IntRange`, `@OneOf`) yet — handler code should still validate invariants that aren't expressible as raw Dart types.
