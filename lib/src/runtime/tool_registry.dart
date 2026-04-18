import '../model/tool_call.dart';
import '../model/tool_definition.dart';
import '../model/tool_error_code.dart';
import '../model/tool_result.dart';

class RegisteredTool {
  const RegisteredTool({required this.definition, required this.handler});

  final ToolDefinition definition;
  final ToolHandler handler;
}

class ToolRegistry {
  final Map<String, RegisteredTool> _tools = {};

  void registerTool({
    required ToolDefinition definition,
    required ToolHandler handler,
  }) {
    _tools[definition.name] = RegisteredTool(
      definition: definition,
      handler: handler,
    );
  }

  List<ToolDefinition> listTools() {
    return _tools.values.map((tool) => tool.definition).toList(growable: false);
  }

  RegisteredTool? find(String toolName) => _tools[toolName];

  Future<ToolResult> invokeRegistered(
    RegisteredTool tool,
    ToolCall call,
  ) async {
    final validationErrors = tool.definition.validateArguments(call.arguments);
    if (validationErrors.isNotEmpty) {
      return ToolResult.fail(
        ToolErrorCode.invalidArguments,
        validationErrors.join('; '),
      );
    }

    return tool.handler(call);
  }

  Future<ToolResult> invoke(ToolCall call) async {
    final tool = find(call.toolName);
    if (tool == null) {
      return ToolResult.fail(
        ToolErrorCode.toolNotFound,
        'Tool ${call.toolName} is not registered.',
      );
    }

    return invokeRegistered(tool, call);
  }
}
