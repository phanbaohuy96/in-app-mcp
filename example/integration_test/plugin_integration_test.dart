// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing


import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_mcp/in_app_mcp.dart';

void main() {
  test('register and execute tool', () async {
    final plugin = InAppMcp(defaultPolicy: ToolPolicy.auto);
    plugin.registerTool(
      definition: const ToolDefinition(
        name: 'ping',
        description: 'Ping test tool',
        argumentTypes: {'value': ToolArgType.string},
        requiredArguments: {'value'},
      ),
      handler: (call) async => ToolResult.ok('pong', data: {'value': call.arguments['value']}),
    );

    final result = await plugin.handleToolCall(
      const ToolCall(id: 'it-1', toolName: 'ping', arguments: {'value': 'ok'}),
    );

    expect(result.success, true);
    expect(result.message, 'pong');
  });
}
