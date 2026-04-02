// FILE: lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  Future<void>? _initFuture;

  static const int _morningId = 100;
  static const int _preEveningId = 101;
  static const int _eveningId = 102;

  static const String _channelId = 'daily_quest_channel';
  static const String _channelName = 'Daily Quests';
  static const String _channelDescription = 'Daily reminders for your quests';

  Future<void> init() async {
    if (_initFuture != null) return _initFuture;
    _initFuture = _initInternal();
    return _initFuture!;
  }

  Future<void> _initInternal() async {
    // Initialize time zones (required for zonedSchedule)
    tz.initializeTimeZones();
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzInfo.identifier));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher'); 

    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // Initializing the plugin with the required 'settings' parameter
    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );

    // Ensure Android channel exists (required for Android 8+ to show notifications)
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  // Request notification permissions (Required for Android 13+)
  Future<void> requestPermission() async {
    await init();
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
      ),
    );
  }

  static const int _dailyMorningId = 200;
  static const int _dailyEveningId = 201;

  Future<void> scheduleDailyQuestReminders() async {
    await requestPermission();

    await _scheduleDailyAtTime(
      id: _dailyMorningId,
      hour: 9,
      minute: 0,
      title: 'Daily Quests Ready! ⚔️',
      body: 'Your new quests are waiting. Earn your XP today!',
    );

    await _scheduleDailyAtTime(
      id: _dailyEveningId,
      hour: 20,
      minute: 0,
      title: "Don't lose your streak! 🛡️",
      body: 'Have you completed your habits? Check in now before the day ends!',
    );
  }

  Future<void> cancelDailyNotifications() async {
    await flutterLocalNotificationsPlugin.cancel(id: _morningId);
    await flutterLocalNotificationsPlugin.cancel(id: _preEveningId);
    await flutterLocalNotificationsPlugin.cancel(id: _eveningId);
  }

  /// Keeps daily reminders in sync with today's quest completion status.
  ///
  /// - Morning (08:00): overview for the day.
  /// - Pre-evening (18:00): gentle nudge if incomplete.
  /// - Evening (20:00): stronger reminder if incomplete.
  Future<void> syncDailyNotifications({
    required int totalQuests,
    required int completedToday,
    int morningHour = 8,
    int morningMinute = 0,
    int preEveningHour = 18,
    int preEveningMinute = 0,
    int eveningHour = 20,
    int eveningMinute = 0,
  }) async {
    final remaining = (totalQuests - completedToday).clamp(0, totalQuests);

    // Morning is always useful (even if 0 quests).
    await _scheduleDaily(
      id: _morningId,
      hour: morningHour,
      minute: morningMinute,
      title: 'Good morning, hero!',
      body: totalQuests == 0
          ? 'Add your first quest to start earning XP today.'
          : 'You have $totalQuests quest${totalQuests == 1 ? '' : 's'} today. Let’s begin!',
    );

    // Evening nudges only if there is something left to do (based on last known state).
    if (remaining > 0) {
      await _scheduleDaily(
        id: _preEveningId,
        hour: preEveningHour,
        minute: preEveningMinute,
        title: 'Quick check-in',
        body: 'You still have $remaining quest${remaining == 1 ? '' : 's'} to validate today.',
      );
      await _scheduleDaily(
        id: _eveningId,
        hour: eveningHour,
        minute: eveningMinute,
        title: 'Night is falling 🌙',
        body: 'Don’t forget: $remaining quest${remaining == 1 ? '' : 's'} still pending today.',
      );
    } else {
      // If everything is done, remove evening reminders.
      await flutterLocalNotificationsPlugin.cancel(id: _preEveningId);
      await flutterLocalNotificationsPlugin.cancel(id: _eveningId);
    }
  }

  Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: _nextInstanceOfTime(hour, minute),
      notificationDetails: _details(),
      // Android 12+ exact alarms require special permission; keep this inexact.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _scheduleDailyAtTime({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    await init();
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: _nextInstanceOfTime(hour, minute),
      notificationDetails: _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // Calculate the next instance of the specified time (e.g., next 8 PM)
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    
    // If the time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}