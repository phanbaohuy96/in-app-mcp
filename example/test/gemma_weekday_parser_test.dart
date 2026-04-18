import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_mcp_example/llm/tool_call_parser.dart';

void main() {
  test('parser extracts weekday names for downstream normalization', () {
    const parser = ToolCallParser();

    final call = parser.parse({
      'rawText':
          '{"toolName":"schedule_weekday_alarm","arguments":{"hour":6,"minute":0,"weekdays":["Monday","Tuesday","Wednesday","Thursday","Friday"]}}',
    });

    expect(call.toolName, 'schedule_weekday_alarm');
    expect(call.arguments['weekdays'], isA<List>());
    expect((call.arguments['weekdays'] as List).length, 5);
  });
}
