import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_mcp_example/llm/tool_call_parser.dart';

void main() {
  test('parser extracts tool call from mixed assistant text', () {
    const parser = ToolCallParser();

    final call = parser.parse({
      'rawText':
          'I can do that. {"toolName":"schedule_weekday_alarm","arguments":{"hour":6,"minute":0,"weekdays":[1,2,3,4,5],"label":"AI Alarm"}}',
    });

    expect(call.toolName, 'schedule_weekday_alarm');
    expect(call.arguments['hour'], 6);
    expect(call.arguments['minute'], 0);
  });
}
