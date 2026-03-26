// FILE: lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Initialize time zones
    tz.initializeTimeZones();

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
  }

  // Request notification permissions (Required for Android 13+)
  Future<void> requestPermission() async {
    flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  }

// Schedule the daily reminder notification
  Future<void> scheduleDailyNotification() async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: 0, 
      title: 'Hero, night is falling! 🌙', 
      body: 'Do not forget to complete your daily quests to earn XP!', 
      scheduledDate: _nextInstanceOfTime(20, 0), // Time: 20:00 (8 PM)
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_quest_channel', // Channel ID
          'Daily Quests', // Channel Name
          channelDescription: 'Daily reminder for your quests',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      // --- FIXED: Changed "exact" to "inexact" to satisfy Android security rules ---
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