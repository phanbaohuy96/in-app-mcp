import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_mcp/in_app_mcp.dart';
import 'package:in_app_mcp_example/agent_tools/echo_tool.dart';

void main() {
  group('codegen echo tool', () {
    test('definition reflects annotation metadata', () {
      expect(echoDefinition.name, 'echo');
      expect(echoDefinition.description, contains('Echo a message'));
      expect(echoDefinition.argumentTypes['message'], ToolArgType.string);
      expect(echoDefinition.argumentTypes['repeat'], ToolArgType.integer);
      expect(echoDefinition.requiredArguments, {'message'});
      expect(echoDefinition.allowAdditionalArguments, isFalse);
    });

    test('handler casts args and invokes the annotated function', () async {
      final mcp = InAppMcp(defaultPolicy: ToolPolicy.auto);
      mcp.registerTool(definition: echoDefinition, handler: echoHandler);

      final result = await mcp.handleToolCall(
        const ToolCall(
          id: 't1',
          toolName: 'echo',
          arguments: {'message': 'hi', 'repeat': 3},
        ),
      );

      expect(result.success, isTrue);
      expect(result.data['message'], 'hi');
      expect(result.data['repeat'], 3);
      expect(result.data['echoed'], ['hi', 'hi', 'hi']);
    });

    test('handler applies default value when caller omits optional arg', () async {
      final mcp = InAppMcp(defaultPolicy: ToolPolicy.auto);
      mcp.registerTool(definition: echoDefinition, handler: echoHandler);

      final result = await mcp.handleToolCall(
        const ToolCall(
          id: 't2',
          toolName: 'echo',
          arguments: {'message': 'hi'},
        ),
      );

      expect(result.success, isTrue);
      expect(result.data['repeat'], 1);
    });
  });
}
