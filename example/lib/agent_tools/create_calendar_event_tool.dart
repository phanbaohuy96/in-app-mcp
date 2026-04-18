import 'package:in_app_mcp/in_app_mcp.dart';
import 'package:url_launcher/url_launcher.dart';

class CreateCalendarEventTool {
  Future<ToolResult> execute(ToolCall call) async {
    final titleValue = call.arguments['title'];
    final startIsoValue = call.arguments['startIso'];
    final endIsoValue = call.arguments['endIso'];

    if (titleValue is! String || titleValue.trim().isEmpty) {
      return ToolResult.fail(
        ToolErrorCode.invalidArguments,
        'title must be a non-empty string.',
      );
    }
    if (startIsoValue is! String || endIsoValue is! String) {
      return ToolResult.fail(
        ToolErrorCode.invalidArguments,
        'startIso and endIso must be ISO-8601 strings.',
      );
    }

    DateTime start;
    DateTime end;
    try {
      start = DateTime.parse(startIsoValue);
      end = DateTime.parse(endIsoValue);
    } catch (_) {
      return ToolResult.fail(
        ToolErrorCode.invalidArguments,
        'startIso and endIso must be parseable ISO-8601 timestamps.',
      );
    }

    if (!end.isAfter(start)) {
      return ToolResult.fail(
        ToolErrorCode.invalidArguments,
        'endIso must be after startIso.',
      );
    }

    final location = (call.arguments['location'] as String?)?.trim();
    final notes = (call.arguments['notes'] as String?)?.trim();

    final uri = Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': titleValue.trim(),
      'dates': '${_toCalendarDate(start)}/${_toCalendarDate(end)}',
      if (location != null && location.isNotEmpty) 'location': location,
      if (notes != null && notes.isNotEmpty) 'details': notes,
    });

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      return ToolResult.fail(
        ToolErrorCode.invalidArguments,
        'Unable to open calendar event composer.',
      );
    }

    return ToolResult.ok(
      'Calendar event composer opened.',
      data: {
        'title': titleValue.trim(),
        'startIso': start.toUtc().toIso8601String(),
        'endIso': end.toUtc().toIso8601String(),
        'url': uri.toString(),
      },
    );
  }

  String _toCalendarDate(DateTime dateTime) {
    final utc = dateTime.toUtc();
    final yyyy = utc.year.toString().padLeft(4, '0');
    final mm = utc.month.toString().padLeft(2, '0');
    final dd = utc.day.toString().padLeft(2, '0');
    final hh = utc.hour.toString().padLeft(2, '0');
    final mi = utc.minute.toString().padLeft(2, '0');
    final ss = utc.second.toString().padLeft(2, '0');
    return '$yyyy$mm${dd}T$hh$mi${ss}Z';
  }
}
