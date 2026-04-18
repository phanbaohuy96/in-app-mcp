import 'package:in_app_mcp/in_app_mcp.dart';
import 'package:in_app_mcp_annotations/in_app_mcp_annotations.dart';

part 'echo_tool.mcp.g.dart';

// In-memory record of every echo the handler has produced. Lets the undoer
// "retract" a prior echo for the Consent Lifecycle showcase — echo itself
// has no real side effect, so we synthesise one.
final List<String> _echoHistory = [];

@McpTool(
  description: 'Echo a message back to the caller. Used to demo codegen.',
)
Future<ToolResult> echo({required String message, int repeat = 1}) async {
  _echoHistory.add(message);
  return ToolResult.ok(
    'Echoed.',
    data: {
      'message': message,
      'repeat': repeat,
      'echoed': List<String>.filled(repeat, message),
      'historyIndex': _echoHistory.length - 1,
    },
  );
}

@McpToolPreview()
Future<Preview> echoPreview({required String message, int repeat = 1}) async {
  final warnings = <PreviewWarning>[];
  if (repeat < 1) {
    warnings.add(
      const PreviewWarning(
        code: 'invalid_repeat',
        message: 'repeat must be >= 1.',
      ),
    );
  }
  final times = repeat == 1 ? 'once' : '$repeat times';
  return Preview(
    summary: 'Would echo "$message" $times.',
    data: {'message': message, 'repeat': repeat},
    warnings: warnings,
  );
}

@McpToolUndo()
Future<ToolResult> echoUndo({required String message, int repeat = 1}) async {
  final index = _echoHistory.lastIndexOf(message);
  if (index < 0) {
    return ToolResult.fail(
      'echo_not_found',
      'No prior echo of "$message" to retract.',
    );
  }
  _echoHistory.removeAt(index);
  return ToolResult.ok(
    'Retracted.',
    data: {'message': message, 'retractedIndex': index},
  );
}
