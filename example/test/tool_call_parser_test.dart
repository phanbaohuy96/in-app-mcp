import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_mcp_example/llm/tool_call_parser.dart';

void main() {
  group('ToolCallParser', () {
    const parser = ToolCallParser();

    test('parses direct tool call map', () {
      final call = parser.parse({
        'id': '1',
        'toolName': 'open_map_directions',
        'arguments': {'destination': 'Tokyo'},
      });

      expect(call.id, '1');
      expect(call.toolName, 'open_map_directions');
      expect(call.arguments['destination'], 'Tokyo');
    });

    test('parses function call payload', () {
      final call = parser.parse({
        'id': '2',
        'functionCall': {
          'name': 'compose_email_draft',
          'arguments': '{"to":"a@b.com","subject":"Hi"}',
        },
      });

      expect(call.id, '2');
      expect(call.toolName, 'compose_email_draft');
      expect(call.arguments['to'], 'a@b.com');
    });

    test('parses raw text that contains JSON object', () {
      final call = parser.parse(
        'Output:\n{"id":"3","toolName":"schedule_weekday_alarm","arguments":{"hour":6,"minute":0,"weekdays":[1,2,3]}}',
      );

      expect(call.id, '3');
      expect(call.toolName, 'schedule_weekday_alarm');
      expect((call.arguments['weekdays'] as List).length, 3);
    });

    test('throws when payload has no tool name', () {
      expect(
        () => parser.parse({'arguments': {}}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
