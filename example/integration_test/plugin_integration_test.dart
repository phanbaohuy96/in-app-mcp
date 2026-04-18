import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_mcp/in_app_mcp.dart';
import 'package:in_app_mcp_example/agent_tools/tool_catalog.dart';

void main() {
  test('executes all catalog tool definitions in auto policy', () async {
    final plugin = InAppMcp(defaultPolicy: ToolPolicy.auto);
    final catalog = ToolCatalog();

    for (final definition in catalog.definitions) {
      plugin.registerTool(
        definition: definition,
        handler: (call) async => ToolResult.ok('ok'),
      );
    }

    final now = DateTime.now().toUtc();

    final results = await Future.wait([
      plugin.handleToolCall(
        const ToolCall(
          id: 'it-1',
          toolName: 'schedule_weekday_alarm',
          arguments: {
            'hour': 6,
            'minute': 0,
            'weekdays': [1, 2, 3],
          },
        ),
      ),
      plugin.handleToolCall(
        ToolCall(
          id: 'it-2',
          toolName: 'create_calendar_event',
          arguments: {
            'title': 'Meeting',
            'startIso': now.toIso8601String(),
            'endIso': now.add(const Duration(hours: 1)).toIso8601String(),
          },
        ),
      ),
      plugin.handleToolCall(
        const ToolCall(
          id: 'it-3',
          toolName: 'open_map_directions',
          arguments: {'destination': 'Tokyo'},
        ),
      ),
      plugin.handleToolCall(
        const ToolCall(
          id: 'it-4',
          toolName: 'compose_email_draft',
          arguments: {'to': 'a@b.com'},
        ),
      ),
    ], eagerError: true);

    for (final result in results) {
      expect(result.success, true);
    }
  });
}
