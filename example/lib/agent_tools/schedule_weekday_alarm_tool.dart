import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:in_app_mcp/in_app_mcp.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class ScheduleWeekdayAlarmTool {
  ScheduleWeekdayAlarmTool({FlutterLocalNotificationsPlugin? notifications})
    : _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _notifications;
  bool _initialized = false;
  bool _permissionsRequested = false;

  static const List<String> _weekdayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOS = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: iOS);

    await _notifications.initialize(settings: settings);
    _initialized = true;
  }

  Future<ToolResult> execute(ToolCall call) async {
    await initialize();

    final hour = call.arguments['hour'] as int;
    final minute = call.arguments['minute'] as int;
    final rawWeekdays = List<dynamic>.from(call.arguments['weekdays'] as List);
    if (!rawWeekdays.every(
      (value) => value is int && value >= 1 && value <= 7,
    )) {
      return ToolResult.fail(
        ToolErrorCode.invalidArguments,
        'weekdays must be a list of integers from 1 to 7.',
      );
    }

    final weekdays = rawWeekdays.cast<int>();
    final label = call.arguments['label'] as String? ?? 'Alarm';

    await _requestPermissions();

    final baseId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final futures = <Future<void>>[];
    final scheduledIds = <int>[];
    for (var index = 0; index < weekdays.length; index++) {
      final weekday = weekdays[index];
      final scheduled = _nextWeekdayAt(weekday, hour, minute);
      final id = baseId + index;
      scheduledIds.add(id);
      futures.add(
        _notifications.zonedSchedule(
          id: id,
          title: label,
          body: 'Scheduled by in_app_mcp',
          scheduledDate: scheduled,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'in_app_mcp_alarm',
              'In-App MCP Alarm',
              channelDescription: 'Scheduled alarms from in_app_mcp example',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        ),
      );
    }
    await Future.wait(futures);

    final nextTrigger = _nextWeekdayAt(weekdays.first, hour, minute);

    return ToolResult.ok(
      'Alarm scheduled.',
      data: {
        'alarmId': baseId.toString(),
        'nextTriggerAt': nextTrigger.toIso8601String(),
        'weekdays': weekdays,
        'scheduledIds': scheduledIds,
      },
    );
  }

  /// Pure previewer. Describes what [execute] would do without scheduling
  /// any notification. Emits a warning when the proposed hour/minute look
  /// templated (classic LLM mistake: literal placeholders).
  Future<Preview> preview(ToolCall call) async {
    final hourRaw = call.arguments['hour'];
    final minuteRaw = call.arguments['minute'];
    final rawWeekdays = call.arguments['weekdays'];
    final label = call.arguments['label'] as String? ?? 'Alarm';

    final warnings = <PreviewWarning>[];
    if (hourRaw is! int || hourRaw < 0 || hourRaw > 23) {
      warnings.add(
        PreviewWarning(
          code: 'invalid_hour',
          message: 'hour "$hourRaw" is not a valid 0-23 integer.',
        ),
      );
    }
    if (minuteRaw is! int || minuteRaw < 0 || minuteRaw > 59) {
      warnings.add(
        PreviewWarning(
          code: 'invalid_minute',
          message: 'minute "$minuteRaw" is not a valid 0-59 integer.',
        ),
      );
    }

    final weekdays = (rawWeekdays is List)
        ? rawWeekdays.whereType<int>().where((d) => d >= 1 && d <= 7).toList()
        : const <int>[];

    if (weekdays.isEmpty) {
      warnings.add(
        const PreviewWarning(
          code: 'no_weekdays',
          message: 'weekdays is empty or contains no valid 1-7 integers.',
        ),
      );
    }

    final time = hourRaw is int && minuteRaw is int
        ? '${hourRaw.toString().padLeft(2, '0')}:${minuteRaw.toString().padLeft(2, '0')}'
        : '??:??';
    final dayLabels = weekdays.isEmpty
        ? 'no days'
        : weekdays.map((d) => _weekdayLabels[d - 1]).join(', ');

    return Preview(
      summary: 'Would schedule "$label" at $time on $dayLabels.',
      data: {
        'label': label,
        'time': time,
        'weekdays': weekdays,
        'notificationCount': weekdays.length,
      },
      warnings: warnings,
    );
  }

  /// Cancels the notifications scheduled by a prior successful [execute].
  /// Reads `scheduledIds` from the original result's data and calls
  /// `cancel` for each.
  Future<ToolResult> undo(ToolCall call, ToolResult original) async {
    final ids = (original.data['scheduledIds'] as List?)
        ?.whereType<int>()
        .toList(growable: false);
    if (ids == null || ids.isEmpty) {
      return ToolResult.fail(
        'undo_missing_ids',
        'Original result has no scheduledIds to cancel.',
      );
    }

    await initialize();
    for (final id in ids) {
      await _notifications.cancel(id: id);
    }
    return ToolResult.ok(
      'Cancelled ${ids.length} scheduled alarm(s).',
      data: {'cancelledIds': ids},
    );
  }

  Future<void> _requestPermissions() async {
    if (_permissionsRequested) {
      return;
    }

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();

    final iosPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);

    final macPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    await macPlugin?.requestPermissions(alert: true, badge: true, sound: true);

    _permissionsRequested = true;
  }

  tz.TZDateTime _nextWeekdayAt(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
