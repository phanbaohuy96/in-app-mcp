# in_app_mcp_annotations — example

This package defines three declarative annotations; pair it with
[`in_app_mcp_gen`](https://pub.dev/packages/in_app_mcp_gen) as a
`dev_dependency` to materialise generated adapters, and with the
[`in_app_mcp`](https://pub.dev/packages/in_app_mcp) runtime to invoke
them.

```dart
import 'package:in_app_mcp/in_app_mcp.dart';
import 'package:in_app_mcp_annotations/in_app_mcp_annotations.dart';

part 'echo_tool.mcp.g.dart';

// `@McpTool` → generator emits `echoDefinition` + `echoHandler(ToolCall)`.
@McpTool(description: 'Echo a message back to the caller.')
Future<ToolResult> echo({required String message, int repeat = 1}) async {
  return ToolResult.ok(
    'Echoed.',
    data: {'message': message, 'repeat': repeat},
  );
}

// `@McpToolPreview` → generator emits `echoPreviewPreviewer(ToolCall)`
// returning `Future<Preview>`. Pure, no side effects.
@McpToolPreview()
Future<Preview> echoPreview({required String message, int repeat = 1}) async {
  return Preview(summary: 'Would echo "$message" $repeat time(s).');
}

// `@McpToolUndo` → generator emits `echoUndoUndoer(ToolCall, ToolResult)`
// for reverse-effect handlers.
@McpToolUndo()
Future<ToolResult> echoUndo({required String message, int repeat = 1}) async {
  return ToolResult.ok('Retracted "$message".');
}
```

Register the generated adapters with the runtime:

```dart
final mcp = InAppMcp();
mcp.registerTool(
  definition: echoDefinition,
  handler: echoHandler,
  previewer: echoPreviewPreviewer,
  undoer: echoUndoUndoer,
);
```

See the [in_app_mcp README](https://pub.dev/packages/in_app_mcp) for the
full Consent Lifecycle walkthrough (preview → ephemeral grant → execute
→ audit → undo) with screenshots.
