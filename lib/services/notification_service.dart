import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_10y.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification clicked with payload: ${response.payload}');
        },
      );
      await requestPermissions();
    } catch (e) {
      debugPrint('Error initializing local notifications: $e');
    }
  }

  static Future<void> requestPermissions() async {
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'sabtrack_channel_general',
      'General Notifications',
      channelDescription: 'Notifications for achievements, streaks, and updates',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(id, title, body, details, payload: payload);
  }

  static Future<void> scheduleDailyReminder(int hour, int minute) async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'sabtrack_channel_workouts',
        'Workout Reminders',
        channelDescription: 'Daily reminders for scheduled workouts',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        playSound: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.zonedSchedule(
        1,
        'Time to move! 🏃‍♂️',
        'It\'s your scheduled workout time. Let\'s get those steps in!',
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'workout',
      );
      debugPrint('Scheduled daily workout reminder at $scheduledDate (ID: 1)');
    } catch (e) {
      debugPrint('Error scheduling workout reminder: $e');
    }
  }

  static Future<void> scheduleWaterReminders(bool enabled) async {
    // Water reminder IDs: 100, 101, 102, 103
    for (int i = 0; i < 4; i++) {
      await _notificationsPlugin.cancel(100 + i);
    }
    
    if (!enabled) {
      debugPrint('Cancelled all water reminders');
      return;
    }

    final reminderTimes = [
      {'hour': 10, 'minute': 0},
      {'hour': 13, 'minute': 0},
      {'hour': 16, 'minute': 0},
      {'hour': 19, 'minute': 0},
    ];

    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'sabtrack_channel_water',
        'Water Reminders',
        channelDescription: 'Reminders to stay hydrated throughout the day',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        playSound: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final now = tz.TZDateTime.now(tz.local);

      for (int i = 0; i < reminderTimes.length; i++) {
        final timeMap = reminderTimes[i];
        final hour = timeMap['hour']!;
        final minute = timeMap['minute']!;

        var scheduledDate = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          hour,
          minute,
        );
        if (scheduledDate.isBefore(now)) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        }

        await _notificationsPlugin.zonedSchedule(
          100 + i,
          'Stay Hydrated! 💧',
          'It\'s time to drink some water and stay energized.',
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'water',
        );
        debugPrint('Scheduled water reminder at $scheduledDate (ID: ${100 + i})');
      }
    } catch (e) {
      debugPrint('Error scheduling water reminders: $e');
    }
  }

  static Future<void> scheduleSupplementNotification({
    required int id,
    required String name,
    required String dosage,
    required String timeStr,
  }) async {
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'sabtrack_channel_supplements',
        'Supplement Reminders',
        channelDescription: 'Reminders to take your logged supplements',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        playSound: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.zonedSchedule(
        id,
        'Time for $name 💊',
        dosage.isNotEmpty ? 'Dosage: $dosage' : 'Take your scheduled supplement.',
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      debugPrint('Scheduled notification for $name at $scheduledDate (ID: $id)');
    } catch (e) {
      debugPrint('Error scheduling supplement notification: $e');
    }
  }

  static Future<void> cancelSupplementNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
      debugPrint('Cancelled notification ID: $id');
    } catch (e) {
      debugPrint('Error cancelling notification: $e');
    }
  }

  static Future<void> scheduleFastingEndReminder(DateTime endTime) async {

    try {
      final tzEndTime = tz.TZDateTime.from(endTime, tz.local);
      if (tzEndTime.isBefore(tz.TZDateTime.now(tz.local))) return;

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'sabtrack_channel_fasting',
        'Fasting Alerts',
        channelDescription: 'Alerts when fast duration ends',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        playSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      );

      await _notificationsPlugin.zonedSchedule(
        50,
        'Fast Completed! 🎉',
        'Congratulations! You completed your scheduled fast target.',
        tzEndTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Error scheduling fasting notification: $e');
    }
  }

  static Future<void> cancelFastingReminder() async {
    await _notificationsPlugin.cancel(50);
  }

  static Future<void> scheduleMealReminders(bool enabled, {int hour = 12, int minute = 30}) async {
    await _notificationsPlugin.cancel(200);
    if (!enabled) return;

    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'sabtrack_channel_meals',
        'Meal Reminders',
        channelDescription: 'Daily reminders to log your meals',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        playSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      );

      await _notificationsPlugin.zonedSchedule(
        200,
        'Meal Time! 🥗',
        'Don\'t forget to log your meal and track your macros!',
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Error scheduling meal reminder: $e');
    }
  }
}

