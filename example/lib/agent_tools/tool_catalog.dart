import 'package:in_app_mcp/in_app_mcp.dart';

import 'compose_email_draft_tool.dart';
import 'create_calendar_event_tool.dart';
import 'echo_tool.dart';
import 'open_map_directions_tool.dart';
import 'schedule_weekday_alarm_tool.dart';

const scheduleWeekdayAlarmDefinition = ToolDefinition(
  name: 'schedule_weekday_alarm',
  description:
      'Set a repeating alarm at a specific hour/minute and weekdays list.',
  argumentTypes: {
    'hour': ToolArgType.integer,
    'minute': ToolArgType.integer,
    'weekdays': ToolArgType.array,
    'label': ToolArgType.string,
  },
  requiredArguments: {'hour', 'minute', 'weekdays'},
  allowAdditionalArguments: false,
);

const createCalendarEventDefinition = ToolDefinition(
  name: 'create_calendar_event',
  description: 'Open calendar to create an event draft.',
  argumentTypes: {
    'title': ToolArgType.string,
    'startIso': ToolArgType.string,
    'endIso': ToolArgType.string,
    'location': ToolArgType.string,
    'notes': ToolArgType.string,
  },
  requiredArguments: {'title', 'startIso', 'endIso'},
  allowAdditionalArguments: false,
);

const openMapDirectionsDefinition = ToolDefinition(
  name: 'open_map_directions',
  description: 'Open map directions to a destination.',
  argumentTypes: {
    'destination': ToolArgType.string,
    'travelMode': ToolArgType.string,
  },
  requiredArguments: {'destination'},
  allowAdditionalArguments: false,
);

const composeEmailDraftDefinition = ToolDefinition(
  name: 'compose_email_draft',
  description: 'Open email app with a prefilled draft.',
  argumentTypes: {
    'to': ToolArgType.string,
    'subject': ToolArgType.string,
    'body': ToolArgType.string,
  },
  requiredArguments: {'to'},
  allowAdditionalArguments: false,
);

class ToolCatalog {
  ToolCatalog({
    ScheduleWeekdayAlarmTool? scheduleTool,
    CreateCalendarEventTool? calendarTool,
    OpenMapDirectionsTool? mapsTool,
    ComposeEmailDraftTool? emailTool,
  }) : _scheduleTool = scheduleTool ?? ScheduleWeekdayAlarmTool(),
       _calendarTool = calendarTool ?? CreateCalendarEventTool(),
       _mapsTool = mapsTool ?? OpenMapDirectionsTool(),
       _emailTool = emailTool ?? ComposeEmailDraftTool();

  final ScheduleWeekdayAlarmTool _scheduleTool;
  final CreateCalendarEventTool _calendarTool;
  final OpenMapDirectionsTool _mapsTool;
  final ComposeEmailDraftTool _emailTool;

  List<ToolDefinition> get definitions => const [
    scheduleWeekdayAlarmDefinition,
    createCalendarEventDefinition,
    openMapDirectionsDefinition,
    composeEmailDraftDefinition,
    echoDefinition,
  ];

  void register(InAppMcp mcp) {
    mcp.registerTool(
      definition: scheduleWeekdayAlarmDefinition,
      handler: _scheduleTool.execute,
      previewer: _scheduleTool.preview,
      undoer: _scheduleTool.undo,
    );
    mcp.registerTool(
      definition: createCalendarEventDefinition,
      handler: _calendarTool.execute,
    );
    mcp.registerTool(
      definition: openMapDirectionsDefinition,
      handler: _mapsTool.execute,
    );
    mcp.registerTool(
      definition: composeEmailDraftDefinition,
      handler: _emailTool.execute,
    );
    mcp.registerTool(
      definition: echoDefinition,
      handler: echoHandler,
      previewer: echoPreviewPreviewer,
      undoer: echoUndoUndoer,
    );
  }
}
