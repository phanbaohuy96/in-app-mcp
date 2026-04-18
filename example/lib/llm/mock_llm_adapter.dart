import 'package:in_app_mcp/in_app_mcp.dart';

import 'llm_adapter.dart';
import 'llm_adapter_mode.dart';
import 'tool_call_parser.dart';

class MockLlmAdapter extends LlmAdapter {
  @override
  LlmAdapterMode get mode => LlmAdapterMode.mock;

  @override
  String get id => 'mock';

  @override
  Future<LlmTurn> buildTurn(String userPrompt) async {
    final normalized = userPrompt.toLowerCase();

    if (normalized.contains('calendar') || normalized.contains('meeting')) {
      final start = DateTime.now().add(const Duration(hours: 1));
      final end = start.add(const Duration(hours: 1));
      return LlmTurn(
        message: 'I can draft a calendar event for you.',
        toolCall: _call('create_calendar_event', {
          'title': 'Team Sync',
          'startIso': start.toUtc().toIso8601String(),
          'endIso': end.toUtc().toIso8601String(),
          'location': 'Main Office',
        }),
      );
    }

    if (normalized.contains('map') || normalized.contains('direction')) {
      return LlmTurn(
        message: 'I can open directions for that destination.',
        toolCall: _call('open_map_directions', {
          'destination': '1600 Amphitheatre Parkway, Mountain View',
          'travelMode': 'driving',
        }),
      );
    }

    if (normalized.contains('email') || normalized.contains('mail')) {
      return LlmTurn(
        message: 'I can prepare an email draft.',
        toolCall: _call('compose_email_draft', {
          'to': 'example@company.com',
          'subject': 'Hello from in_app_mcp',
          'body': 'Drafted by the mock MCP adapter.',
        }),
      );
    }

    if (normalized.contains('alarm') || normalized.contains('wake')) {
      final isWeekdayRequest =
          normalized.contains('week') || normalized.contains('workday');
      final weekdays = isWeekdayRequest
          ? <int>[1, 2, 3, 4, 5]
          : <int>[1, 2, 3, 4, 5, 6, 7];

      return LlmTurn(
        message: 'I can schedule that alarm for you.',
        toolCall: _call('schedule_weekday_alarm', {
          'hour': 6,
          'minute': 0,
          'weekdays': weekdays,
          'label': 'AI Alarm',
        }),
      );
    }

    return const LlmTurn(
      message:
          'I can help with alarms, calendar events, maps directions, or email drafts. Tell me what you want to do.',
    );
  }

  ToolCall _call(String toolName, Map<String, dynamic> arguments) {
    return ToolCall(
      id: newToolCallId(),
      toolName: toolName,
      arguments: arguments,
    );
  }
}
