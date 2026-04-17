import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_mcp/in_app_mcp.dart';

void main() {
  group('in_app_mcp runtime', () {
    test('returns tool_not_found for unknown tool', () async {
      final mcp = InAppMcp();
      final result = await mcp.handleToolCall(
        const ToolCall(id: '1', toolName: 'missing', arguments: {}),
      );

      expect(result.success, isFalse);
      expect(result.code, 'tool_not_found');
    });

    test('blocks when policy is deny', () async {
      final mcp = InAppMcp();
      mcp.registerTool(
        definition: const ToolDefinition(
          name: 'x',
          description: 'x',
          argumentTypes: {'hour': ToolArgType.integer},
          requiredArguments: {'hour'},
          allowAdditionalArguments: false,
        ),
        handler: (call) async => ToolResult.ok('done'),
      );

      await mcp.setToolPolicy('x', ToolPolicy.deny);
      final result = await mcp.handleToolCall(
        const ToolCall(id: '2', toolName: 'x', arguments: {'hour': 6}),
      );

      expect(result.success, isFalse);
      expect(result.code, 'policy_denied');
    });

    test('requires confirmation when policy is confirm', () async {
      final mcp = InAppMcp();
      mcp.registerTool(
        definition: const ToolDefinition(
          name: 'x',
          description: 'x',
          argumentTypes: {'hour': ToolArgType.integer},
          requiredArguments: {'hour'},
          allowAdditionalArguments: false,
        ),
        handler: (call) async => ToolResult.ok('done'),
      );

      await mcp.setToolPolicy('x', ToolPolicy.confirm);
      final result = await mcp.handleToolCall(
        const ToolCall(id: '3', toolName: 'x', arguments: {'hour': 6}),
      );

      expect(result.success, isFalse);
      expect(result.code, 'confirmation_required');
    });

    test('executes when confirmed', () async {
      final mcp = InAppMcp();
      mcp.registerTool(
        definition: const ToolDefinition(
          name: 'x',
          description: 'x',
          argumentTypes: {'hour': ToolArgType.integer},
          requiredArguments: {'hour'},
          allowAdditionalArguments: false,
        ),
        handler: (call) async => ToolResult.ok('done', data: {'ok': true}),
      );

      await mcp.setToolPolicy('x', ToolPolicy.confirm);
      final result = await mcp.handleToolCall(
        const ToolCall(id: '4', toolName: 'x', arguments: {'hour': 6}),
        confirmed: true,
      );

      expect(result.success, isTrue);
      expect(result.message, 'done');
      expect(result.data['ok'], true);
    });

    test('validates argument schema', () async {
      final mcp = InAppMcp(defaultPolicy: ToolPolicy.auto);
      mcp.registerTool(
        definition: const ToolDefinition(
          name: 'x',
          description: 'x',
          argumentTypes: {'hour': ToolArgType.integer},
          requiredArguments: {'hour'},
          allowAdditionalArguments: false,
        ),
        handler: (call) async => ToolResult.ok('done'),
      );

      final result = await mcp.handleToolCall(
        const ToolCall(id: '5', toolName: 'x', arguments: {'hour': '6'}),
      );

      expect(result.success, isFalse);
      expect(result.code, 'invalid_arguments');
    });
  });
}
