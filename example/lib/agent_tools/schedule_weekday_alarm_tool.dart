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
    if (!rawWeekdays.every((value) => value is int && value >= 1 && value <= 7)) {
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
    for (var index = 0; index < weekdays.length; index++) {
      final weekday = weekdays[index];
      final scheduled = _nextWeekdayAt(weekday, hour, minute);
      futures.add(
        _notifications.zonedSchedule(
          id: baseId + index,
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
      },
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
