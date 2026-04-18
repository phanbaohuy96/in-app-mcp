# in_app_mcp_gen — example

`in_app_mcp_gen` is a `build_runner` code generator. Wire it into your
app's `build.yaml`:

```yaml
targets:
  $default:
    builders:
      in_app_mcp_gen:in_app_mcp:
        enabled: true
```

Then for every top-level function annotated with
[`@McpTool`](https://pub.dev/documentation/in_app_mcp_annotations/latest/in_app_mcp_annotations/McpTool-class.html),
[`@McpToolPreview`](https://pub.dev/documentation/in_app_mcp_annotations/latest/in_app_mcp_annotations/McpToolPreview-class.html),
or [`@McpToolUndo`](https://pub.dev/documentation/in_app_mcp_annotations/latest/in_app_mcp_annotations/McpToolUndo-class.html),
`build_runner build` emits a `<source>.mcp.g.dart` part file containing
the matching typed adapter.

Given:

```dart
// lib/echo_tool.dart
import 'package:in_app_mcp/in_app_mcp.dart';
import 'package:in_app_mcp_annotations/in_app_mcp_annotations.dart';

part 'echo_tool.mcp.g.dart';

@McpTool(description: 'Echo a message back to the caller.')
Future<ToolResult> echo({required String message}) async =>
    ToolResult.ok('Echoed.', data: {'message': message});

@McpToolPreview()
Future<Preview> echoPreview({required String message}) async =>
    Preview(summary: 'Would echo "$message".');

@McpToolUndo()
Future<ToolResult> echoUndo({required String message}) async =>
    ToolResult.ok('Retracted "$message".');
```

The generator emits:

```dart
// lib/echo_tool.mcp.g.dart (excerpt)
const ToolDefinition echoDefinition = ToolDefinition(
  name: 'echo',
  description: 'Echo a message back to the caller.',
  argumentTypes: {'message': ToolArgType.string},
  requiredArguments: {'message'},
  allowAdditionalArguments: false,
);

Future<ToolResult> echoHandler(ToolCall call) =>
    echo(message: call.arguments['message'] as String);

Future<Preview> echoPreviewPreviewer(ToolCall call) =>
    echoPreview(message: call.arguments['message'] as String);

Future<ToolResult> echoUndoUndoer(ToolCall call, ToolResult original) =>
    echoUndo(message: call.arguments['message'] as String);
```

Register them with the runtime:

```dart
final mcp = InAppMcp();
mcp.registerTool(
  definition: echoDefinition,
  handler: echoHandler,
  previewer: echoPreviewPreviewer,
  undoer: echoUndoUndoer,
);
```

See [`in_app_mcp`](https://pub.dev/packages/in_app_mcp) for the full
Consent Lifecycle walkthrough.
