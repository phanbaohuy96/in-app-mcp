import 'package:in_app_mcp/in_app_mcp.dart';
import 'package:in_app_mcp_annotations/in_app_mcp_annotations.dart';

part 'echo_tool.mcp.g.dart';

@McpTool(description: 'Echo a message back to the caller. Used to demo codegen.')
Future<ToolResult> echo({
  required String message,
  int repeat = 1,
}) async {
  return ToolResult.ok(
    'Echoed.',
    data: {
      'message': message,
      'repeat': repeat,
      'echoed': List<String>.filled(repeat, message),
    },
  );
}
