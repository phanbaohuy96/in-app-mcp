# in_app_mcp_annotations

Annotations consumed by [`in_app_mcp_gen`](https://pub.dev/packages/in_app_mcp_gen) to generate `ToolDefinition`s and typed handler adapters for [`in_app_mcp`](https://pub.dev/packages/in_app_mcp).

This package has zero runtime dependencies. It only defines annotation classes.

```dart
import 'package:in_app_mcp_annotations/in_app_mcp_annotations.dart';
import 'package:in_app_mcp/in_app_mcp.dart';

part 'my_tools.mcp.g.dart';

@McpTool(description: 'Echo a message back to the caller.')
Future<ToolResult> echo({required String message}) async {
  return ToolResult.ok('ok', data: {'echo': message});
}
```

See the `in_app_mcp_gen` README for the build-runner setup.
