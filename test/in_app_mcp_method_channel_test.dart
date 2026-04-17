import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_mcp/in_app_mcp.dart';

void main() {
  test('ToolResult toJson includes fields', () {
    final result = ToolResult.ok('ok', data: {'a': 1});
    final json = result.toJson();

    expect(json['success'], true);
    expect(json['message'], 'ok');
    expect(json['data'], {'a': 1});
  });

  test('ToolCall fromJson parses fields', () {
    final call = ToolCall.fromJson({
      'id': 'abc',
      'toolName': 'test_tool',
      'arguments': {'x': 1},
      'requestId': 'r1',
    });

    expect(call.id, 'abc');
    expect(call.toolName, 'test_tool');
    expect(call.arguments['x'], 1);
    expect(call.requestId, 'r1');
  });
}
