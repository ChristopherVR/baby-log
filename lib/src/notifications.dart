import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';
import 'routines.dart';
import 'localization.dart';

/// A reminder that went off, from its notification's payload.
class ReminderInfo {
  final int id;
  final String kind; // 'feed', 'pill' or 'routine'
  final String? medId;
  final String? babyId;
  final String? language;
  final String title;
  final String body;
  final bool alarm;

  const ReminderInfo({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    this.medId,
    this.babyId,
    this.language,
    this.alarm = false,
  });

  String toPayload() => jsonEncode({
    'id': id,
    'kind': kind,
    'medId': ?medId,
    'babyId': ?babyId,
    'language': language ?? AppLanguage.code,
    'title': tr(title),
    'body': tr(body),
    // Read by MainActivity.kt to show the alarm over the lock screen.
    'alarm': alarm,
  });

  ReminderInfo withId(int newId) => ReminderInfo(
    id: newId,
    kind: kind,
    medId: medId,
    babyId: babyId,
    language: language,
    title: title,
    body: body,
    alarm: alarm,
  );

  static ReminderInfo? parse(String? payload) {
    if (payload == null) return null;
    try {
      final j = jsonDecode(payload) as Map<String, dynamic>;
      return ReminderInfo(
        id: (j['id'] as num).toInt(),
        kind: j['kind'] as String,
        medId: j['medId'] as String?,
        babyId: j['babyId'] as String?,
        language: j['language'] == 'af' ? 'af' : 'en',
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        alarm: j['alarm'] == true,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Snooze pressed on a notification while the app was closed: runs in a
/// background isolate started by the notifications plugin.
@pragma('vm:entry-point')
Future<void> reminderActionInBackground(NotificationResponse response) async {
  DartPluginRegistrant.ensureInitialized();
  final info = ReminderInfo.parse(response.payload);
  if (response.actionId != Reminders.snoozeAction || info == null) return;
  AppLanguage.use(info.language ?? 'en');
  final reminders = Reminders();
  await reminders._initPlugin();
  await reminders.snooze(info);
}

/// Schedules feed and pill reminders, either as normal notifications or as
/// alarms (alarm sound that keeps ringing, full screen on the lock screen,
/// Stop and Snooze buttons).
class Reminders {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  Future<void> _queue = Future.value();

  static const _timerChannel = MethodChannel('babylog/feeding_timer');
  final timerProblem = ValueNotifier<String?>(null);
  String? _timerPlan;
  Future<void> _timerQueue = Future.value();
  Timer? _desktopTimer;

  /// Android owns the recurring schedule, even when the Dart process is gone.
  /// Desktop notifications are for testing and run while the app is open.
  void scheduleFeedingTimer({
    required DateTime? origin,
    required String babyName,
  }) {
    if (!_ready) return;
    final plan =
        '${origin?.millisecondsSinceEpoch}:$babyName:${AppLanguage.code}';
    if (_timerPlan == plan) return;
    _timerPlan = plan;
    final title = tr('Feeding check-in');
    final body = tr(
      'Another 5 minutes of feeding. Open Nestling to pause or finish.',
    );
    _timerQueue = _timerQueue
        .then((_) async {
          _desktopTimer?.cancel();
          if (Platform.isAndroid) {
            await _timerChannel.invokeMethod<void>('schedule', {
              'origin': origin?.millisecondsSinceEpoch,
              'title': babyName.isEmpty ? title : '$babyName · $title',
              'body': body,
            });
          } else {
            await _plugin.cancel(id: 2000000);
            if (origin != null) {
              void next() {
                final now = DateTime.now();
                const interval = Duration(minutes: 5);
                final elapsed = now.difference(origin).inMilliseconds;
                final delay =
                    interval.inMilliseconds - elapsed % interval.inMilliseconds;
                _desktopTimer = Timer(Duration(milliseconds: delay), () async {
                  if (_timerPlan != plan) return;
                  try {
                    await _plugin.show(
                      id: 2000000,
                      title: title,
                      body: body,
                      notificationDetails: const NotificationDetails(
                        windows: WindowsNotificationDetails(),
                      ),
                    );
                  } catch (e) {
                    timerProblem.value = tr(
                      'Feeding reminders are unavailable. Check notification permissions.',
                    );
                  }
                  if (_timerPlan == plan) next();
                });
              }

              next();
            }
          }
          timerProblem.value = null;
        })
        .catchError((Object error) {
          _timerPlan = null;
          timerProblem.value = tr(
            'Feeding reminders are unavailable. Check notification permissions.',
          );
          debugPrint('Feeding reminder failed: $error');
        });
  }

  void dispose() {
    _desktopTimer?.cancel();
  }

  static const snoozeAction = 'snooze';
  static const stopAction = 'stop';
  static const snoozeMinutes = 10;

  /// Ids: 1 = legacy feed, 100+ = pill slots, 900–999 = snoozed reminders,
  /// 1000+ = routine weekdays, 1000000+ = per-baby feed reminders.
  static const _feedId = 1;
  static const _snoozeBase = 900;

  /// Called when a reminder is opened (tapped, or shown full screen).
  void Function(ReminderInfo info)? onOpen;

  /// The reminder that launched the app, if any.
  ReminderInfo? launchedWith;

  static NotificationDetails _details({
    required bool alarm,
    required ReminderInfo info,
  }) => NotificationDetails(
    android: alarm
        ? AndroidNotificationDetails(
            'alarms',
            'Alarms',
            channelDescription:
                'Feed and pill reminders that ring like an alarm clock',
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            fullScreenIntent: true,
            audioAttributesUsage: AudioAttributesUsage.alarm,
            sound: const UriAndroidNotificationSound(
              'content://settings/system/alarm_alert',
            ),
            // FLAG_INSISTENT: the sound repeats until the alarm is stopped.
            additionalFlags: Int32List.fromList(const [4]),
            ongoing: true,
            autoCancel: false,
            visibility: NotificationVisibility.public,
            // Stops ringing by itself after 15 minutes.
            timeoutAfter: 15 * 60 * 1000,
            actions: [
              AndroidNotificationAction(
                snoozeAction,
                tr('Snooze $snoozeMinutes min'),
              ),
              AndroidNotificationAction(stopAction, tr('Stop')),
            ],
          )
        : AndroidNotificationDetails(
            'reminders',
            'Reminders',
            channelDescription: 'Feed and pill reminders',
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
            actions: [
              AndroidNotificationAction(
                snoozeAction,
                tr('Snooze $snoozeMinutes min'),
              ),
            ],
          ),
    windows: const WindowsNotificationDetails(),
  );

  static const _initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    windows: WindowsInitializationSettings(
      appName: 'Nestling',
      appUserModelId: 'BabyApp.BabyLog',
      guid: '6f1d6c39-2a3e-4d7b-9b8e-3c2f4a5e7d10',
    ),
  );

  Future<void> _initPlugin() async {
    tzdata.initializeTimeZones();
    await _plugin.initialize(settings: _initSettings);
    _ready = true;
  }

  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      await _setLocalTimezone();
      await _plugin.initialize(
        settings: _initSettings,
        onDidReceiveNotificationResponse: _onResponse,
        onDidReceiveBackgroundNotificationResponse: reminderActionInBackground,
      );
      _ready = true;
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true &&
          launch!.notificationResponse?.actionId == null) {
        launchedWith = ReminderInfo.parse(launch.notificationResponse?.payload);
      }
    } catch (e) {
      debugPrint('Reminders unavailable: $e');
      timerProblem.value = tr(
        'Feeding reminders are unavailable. Check notification permissions.',
      );
    }
  }

  void _onResponse(NotificationResponse response) {
    final info = ReminderInfo.parse(response.payload);
    if (info == null) return;
    switch (response.actionId) {
      case snoozeAction:
        snooze(info);
      case stopAction:
        break;
      default:
        onOpen?.call(info);
    }
  }

  /// Asks Android for permission to show notifications (once; later calls do nothing).
  Future<void> requestPermission() async {
    try {
      await _android?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
  }

  /// Alarms show full screen on the lock screen; newer Android asks the user
  /// for that once (opens its settings page only if not yet allowed).
  Future<void> requestAlarmPermission() async {
    try {
      await _android?.requestNotificationsPermission();
      await _android?.requestFullScreenIntentPermission();
    } catch (e) {
      debugPrint('Alarm permission request failed: $e');
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Stops a ringing reminder.
  Future<void> stop(ReminderInfo info) async {
    if (_ready) await _plugin.cancel(id: info.id);
  }

  /// Stops [info] and rings again in [snoozeMinutes].
  Future<void> snooze(ReminderInfo info) async {
    if (!_ready) return;
    await _plugin.cancel(id: info.id);
    final again = info.withId(
      _snoozeBase +
          (info.kind == 'feed' && info.babyId == null
              ? 0
              : 1 +
                    '${info.kind}:${info.medId ?? info.babyId ?? ''}:${info.title}'
                            .hashCode
                            .abs() %
                        90),
    );
    await _plugin.zonedSchedule(
      id: again.id,
      title: tr(again.title),
      body: tr('${again.body} (snoozed)'),
      scheduledDate: tz.TZDateTime.from(
        DateTime.now().add(const Duration(minutes: snoozeMinutes)),
        tz.UTC,
      ),
      notificationDetails: _details(alarm: again.alarm, info: again),
      payload: again.toPayload(),
      androidScheduleMode: again.alarm
          ? AndroidScheduleMode.alarmClock
          : AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> _setLocalTimezone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
      return;
    } catch (_) {
      // Windows can report names like "South Africa Standard Time"; fall back
      // to any zone with the same current UTC offset.
    }
    final offset = DateTime.now().timeZoneOffset.inMilliseconds;
    for (final loc in tz.timeZoneDatabase.locations.values) {
      if (tz.TZDateTime.now(loc).timeZoneOffset.inMilliseconds == offset) {
        tz.setLocalLocation(loc);
        return;
      }
    }
  }

  String? _lastPlan;

  /// Schedules the feed reminder and a daily reminder per dose time of
  /// [meds], as alarms or notifications. Does nothing if the plan is the same
  /// as last time.
  void reschedule({
    DateTime? feedReminderAt,
    required List<Medication> meds,
    bool feedAlarm = false,
    bool pillAlarm = false,
    Map<String, String> pillReminderOverrides = const {},
    List<({String babyId, String name, DateTime? at})> babyFeeds = const [],
    List<({Routine routine, String babyName, DateTime? completedAt})>
        routineReminders =
        const [],
  }) {
    final plan = [
      AppLanguage.code,
      feedReminderAt?.millisecondsSinceEpoch,
      feedAlarm,
      pillAlarm,
      for (final b in babyFeeds)
        '${b.babyId}:${b.name}:${b.at?.millisecondsSinceEpoch}',
      for (final r in routineReminders)
        '${r.babyName}:${jsonEncode(r.routine.toJson())}:${r.completedAt?.millisecondsSinceEpoch}',
      ...pillReminderOverrides.entries.map((e) => '${e.key}:${e.value}'),
      for (final m in meds) '${m.id}:${m.name}:${m.dose}:${m.slots.join(',')}',
    ].join('|');
    if (plan == _lastPlan) return;
    _lastPlan = plan;
    _queue = _queue
        .then(
          (_) => _reschedule(
            feedReminderAt,
            meds,
            feedAlarm,
            pillAlarm,
            pillReminderOverrides,
            babyFeeds,
            routineReminders,
          ),
        )
        .catchError((Object e) {
          _lastPlan = null;
          debugPrint('Scheduling reminders failed: $e');
        });
  }

  Future<void> _reschedule(
    DateTime? feedAt,
    List<Medication> meds,
    bool feedAlarm,
    bool pillAlarm,
    Map<String, String> pillReminderOverrides,
    List<({String babyId, String name, DateTime? at})> babyFeeds,
    List<({Routine routine, String babyName, DateTime? completedAt})>
    routineReminders,
  ) async {
    if (!_ready) return;
    if (Platform.isAndroid) {
      // Cancel the scheduled reminders but keep snoozed ones.
      for (final p in await _plugin.pendingNotificationRequests()) {
        if (p.id < _snoozeBase || p.id >= 1000) await _plugin.cancel(id: p.id);
      }
    } else {
      await _plugin.cancelAll();
    }
    final now = DateTime.now();

    var routineId = 1000;
    for (final item in routineReminders) {
      final r = item.routine;
      final localNow = tz.TZDateTime.now(tz.local);
      for (final day in r.weekdays) {
        final offset = (day - localNow.weekday + 7) % 7;
        var at = tz.TZDateTime(
          tz.local,
          localNow.year,
          localNow.month,
          localNow.day + offset,
          r.minutes ~/ 60,
          r.minutes % 60,
        );
        final completed = item.completedAt;
        final doneOnDate =
            completed != null &&
            completed.year == at.year &&
            completed.month == at.month &&
            completed.day == at.day;
        if (!at.isAfter(localNow) || doneOnDate) {
          at = tz.TZDateTime(
            tz.local,
            localNow.year,
            localNow.month,
            localNow.day + offset + 7,
            r.minutes ~/ 60,
            r.minutes % 60,
          );
        }
        final info = ReminderInfo(
          id: routineId++,
          kind: 'routine',
          babyId: r.babyId,
          title:
              '${item.babyName.isEmpty ? tr('Baby') : item.babyName}: ${r.name}',
          body: r.notes.isEmpty ? 'Time for ${r.name.toLowerCase()}' : r.notes,
        );
        await _plugin.zonedSchedule(
          id: info.id,
          title: tr(info.title),
          body: tr(info.body),
          scheduledDate: at,
          notificationDetails: _details(alarm: false, info: info),
          payload: info.toPayload(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    }
    var babyFeedId = 1000000;
    for (final b in babyFeeds) {
      if (b.at == null || !b.at!.isAfter(now)) continue;
      final info = ReminderInfo(
        id: babyFeedId++,
        kind: 'feed',
        babyId: b.babyId,
        title: '${b.name.isEmpty ? tr('Baby') : b.name}: time for a feed',
        body: 'Reminder you set after the last feed',
        alarm: feedAlarm,
      );
      await _plugin.zonedSchedule(
        id: info.id,
        title: tr(info.title),
        body: tr(info.body),
        scheduledDate: tz.TZDateTime.from(b.at!, tz.local),
        notificationDetails: _details(alarm: feedAlarm, info: info),
        payload: info.toPayload(),
        androidScheduleMode: feedAlarm
            ? AndroidScheduleMode.alarmClock
            : AndroidScheduleMode.exactAllowWhileIdle,
      );
    }

    if (feedAt != null && feedAt.isAfter(now)) {
      final info = ReminderInfo(
        id: _feedId,
        kind: 'feed',
        title: 'Time for a feed',
        body: 'Reminder you set after the last feed',
        alarm: feedAlarm,
      );
      await _plugin.zonedSchedule(
        id: info.id,
        title: tr(info.title),
        body: tr(info.body),
        scheduledDate: tz.TZDateTime.from(feedAt, tz.local),
        notificationDetails: _details(alarm: feedAlarm, info: info),
        payload: info.toPayload(),
        androidScheduleMode: feedAlarm
            ? AndroidScheduleMode.alarmClock
            : AndroidScheduleMode.exactAllowWhileIdle,
      );
    }

    var id = 100;
    final tzNow = tz.TZDateTime.now(tz.local);
    for (final med in meds) {
      if (med.deleted) continue;
      for (final slot in med.slots) {
        final override = pillReminderOverrides['${med.id}:$slot'];
        if (override == 'off') continue;
        final alarm =
            override == 'alarm' || (override != 'notification' && pillAlarm);
        var at = tz.TZDateTime(
          tz.local,
          tzNow.year,
          tzNow.month,
          tzNow.day,
          slot ~/ 60,
          slot % 60,
        );
        if (!at.isAfter(tzNow)) {
          at = tz.TZDateTime(
            tz.local,
            tzNow.year,
            tzNow.month,
            tzNow.day + 1,
            slot ~/ 60,
            slot % 60,
          );
        }
        final info = ReminderInfo(
          id: id++,
          kind: 'pill',
          medId: med.id,
          title: 'Pill time: ${med.name}',
          body: med.dose.isEmpty
              ? 'Time to take your ${med.name}'
              : 'Take ${med.dose}',
          alarm: alarm,
        );
        await _plugin.zonedSchedule(
          id: info.id,
          title: tr(info.title),
          body: tr(info.body),
          scheduledDate: at,
          notificationDetails: _details(alarm: alarm, info: info),
          payload: info.toPayload(),
          androidScheduleMode: alarm
              ? AndroidScheduleMode.alarmClock
              : AndroidScheduleMode.exactAllowWhileIdle,
          // Repeats daily at the same time (Android only; Windows is for testing).
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    }
  }
}
