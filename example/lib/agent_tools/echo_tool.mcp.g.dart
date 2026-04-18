// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

part of 'echo_tool.dart';

// **************************************************************************
// McpToolGenerator
// **************************************************************************

const ToolDefinition echoDefinition = ToolDefinition(
  name: 'echo',
  description: 'Echo a message back to the caller. Used to demo codegen.',
  argumentTypes: {'message': ToolArgType.string, 'repeat': ToolArgType.integer},
  requiredArguments: {'message'},
  allowAdditionalArguments: false,
);

Future<ToolResult> echoHandler(ToolCall call) {
  return echo(
    message: call.arguments['message'] as String,
    repeat: call.arguments['repeat'] as int? ?? 1,
  );
}
