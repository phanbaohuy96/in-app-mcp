import 'package:in_app_mcp/in_app_mcp.dart';

import 'schedule_weekday_alarm_tool.dart';

class ToolCatalog {
  ToolCatalog({ScheduleWeekdayAlarmTool? scheduleTool})
      : _scheduleTool = scheduleTool ?? ScheduleWeekdayAlarmTool();

  final ScheduleWeekdayAlarmTool _scheduleTool;

  void register(InAppMcp mcp) {
    mcp.registerTool(
      definition: const ToolDefinition(
        name: 'schedule_weekday_alarm',
        description: 'Schedule repeating alarm notifications by weekdays.',
        argumentTypes: {
          'hour': ToolArgType.integer,
          'minute': ToolArgType.integer,
          'weekdays': ToolArgType.array,
          'label': ToolArgType.string,
        },
        requiredArguments: {'hour', 'minute', 'weekdays'},
        allowAdditionalArguments: false,
      ),
      handler: _scheduleTool.execute,
    );
  }
}
