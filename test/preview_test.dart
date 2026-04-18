import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_mcp/in_app_mcp.dart';

void main() {
  group('Preview', () {
    test('toJson serialises summary, data, and warnings', () {
      const preview = Preview(
        summary: 'Would echo: hello',
        data: {'message': 'hello'},
        warnings: [
          PreviewWarning(code: 'templated', message: 'message looks templated'),
        ],
      );

      expect(preview.toJson(), {
        'summary': 'Would echo: hello',
        'data': {'message': 'hello'},
        'warnings': [
          {'code': 'templated', 'message': 'message looks templated'},
        ],
      });
    });
  });

  group('InAppMcp previewer', () {
    test(
      'previewToolCall returns null when no previewer is registered',
      () async {
        final mcp = InAppMcp();
        mcp.registerTool(
          definition: const ToolDefinition(
            name: 'x',
            description: 'x',
            argumentTypes: {},
          ),
          handler: (call) async => ToolResult.ok('done'),
        );

        expect(
          await mcp.previewToolCall(
            const ToolCall(id: '1', toolName: 'x', arguments: {}),
          ),
          isNull,
        );
      },
    );

    test(
      'previewToolCall returns the previewer output without side effects',
      () async {
        final mcp = InAppMcp();
        var handlerCalled = false;
        mcp.registerTool(
          definition: const ToolDefinition(
            name: 'x',
            description: 'x',
            argumentTypes: {'message': ToolArgType.string},
            requiredArguments: {'message'},
          ),
          handler: (call) async {
            handlerCalled = true;
            return ToolResult.ok('done');
          },
          previewer: (call) async => Preview(
            summary: 'Would echo: ${call.arguments['message']}',
            data: {'message': call.arguments['message']},
          ),
        );

        final preview = await mcp.previewToolCall(
          const ToolCall(
            id: '1',
            toolName: 'x',
            arguments: {'message': 'hello'},
          ),
        );
        expect(preview?.summary, 'Would echo: hello');
        expect(preview?.data['message'], 'hello');
        expect(handlerCalled, isFalse);
      },
    );

    test('previewToolCall returns null for unknown tools', () async {
      final mcp = InAppMcp();
      expect(
        await mcp.previewToolCall(
          const ToolCall(id: '1', toolName: 'missing', arguments: {}),
        ),
        isNull,
      );
    });

    test('previewer runs independently of policy decisions', () async {
      // Even when a tool is denied, preview must still work — the UI uses
      // it to show the user what the LLM *proposed*.
      final mcp = InAppMcp();
      mcp.registerTool(
        definition: const ToolDefinition(
          name: 'x',
          description: 'x',
          argumentTypes: {},
        ),
        handler: (call) async => ToolResult.ok('done'),
        previewer: (call) async => const Preview(summary: 'preview ok'),
      );
      await mcp.setToolPolicy('x', ToolPolicy.deny);

      final preview = await mcp.previewToolCall(
        const ToolCall(id: '1', toolName: 'x', arguments: {}),
      );
      expect(preview?.summary, 'preview ok');
    });
  });
}
