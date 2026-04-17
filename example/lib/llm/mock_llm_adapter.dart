import 'package:in_app_mcp/in_app_mcp.dart';

import 'llm_adapter.dart';

class MockLlmAdapter implements LlmAdapter {
  @override
  Future<ToolCall> buildToolCall(String userPrompt) async {
    final normalized = userPrompt.toLowerCase();
    final isWeekdayRequest = normalized.contains('week') || normalized.contains('workday');

    final weekdays = isWeekdayRequest
        ? <int>[1, 2, 3, 4, 5]
        : <int>[1, 2, 3, 4, 5, 6, 7];

    return ToolCall(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      toolName: 'schedule_weekday_alarm',
      arguments: {
        'hour': 6,
        'minute': 0,
        'weekdays': weekdays,
        'label': 'AI Alarm',
      },
    );
  }
}
