import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_mcp/in_app_mcp.dart';
import 'package:in_app_mcp_example/llm/tool_call_parser.dart';

void main() {
  test('parser accepts strict JSON tool call payload used by Gemma retry', () {
    const parser = ToolCallParser();

    final call = parser.parse({
      'rawText':
          '{"toolName":"schedule_weekday_alarm","arguments":{"hour":6,"minute":0,"weekdays":[1,2,3,4,5]}}',
    }, fallbackId: 'retry-1');

    expect(call.id, 'retry-1');
    expect(call.toolName, 'schedule_weekday_alarm');
    expect(call.arguments['hour'], 6);
    expect(call.arguments['minute'], 0);
  });

  test('parser throws on plain text with no JSON', () {
    const parser = ToolCallParser();

    expect(
      () => parser.parse({'rawText': 'I cannot set alarms directly.'}),
      throwsA(isA<FormatException>()),
    );
  });

  test('tool call JSON can be converted to ToolCall directly', () {
    final call = const ToolCall(
      id: 'direct-1',
      toolName: 'schedule_weekday_alarm',
      arguments: {
        'hour': 6,
        'minute': 0,
        'weekdays': [1, 2, 3, 4, 5],
      },
    );

    expect(call.toolName, 'schedule_weekday_alarm');
    expect(call.arguments['hour'], 6);
  });
}
