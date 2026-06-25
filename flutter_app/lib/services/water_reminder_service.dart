import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class WaterReminderService {
  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  
  static bool _initialized = false;
  
  /// Initialize the notification plugin
  static Future<void> init() async {
    if (_initialized) return;
    
    // Initialize timezone data
    tz_data.initializeTimeZones();
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(initSettings);
    
    // Create Android notification channel
    const androidChannel = AndroidNotificationChannel(
      'water_reminder_channel',
      'Water Reminders',
      description: 'Reminders to drink water',
      importance: Importance.high,
    );
    
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
    
    _initialized = true;
    debugPrint('💧 Water reminder service initialized');
  }
  
  /// Check if reminders are enabled
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('water_reminder_enabled') ?? false;
  }
  
  /// Get reminder interval in hours
  static Future<int> getIntervalHours() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('water_reminder_interval') ?? 2;
  }
  
  /// Enable/disable water reminders
  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('water_reminder_enabled', enabled);
    
    if (enabled) {
      await _scheduleReminders();
    } else {
      await cancelAll();
    }
  }
  
  /// Set reminder interval
  static Future<void> setIntervalHours(int hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('water_reminder_interval', hours);
    
    // Reschedule with new interval
    if (await isEnabled()) {
      await _scheduleReminders();
    }
  }
  
  /// Schedule periodic water reminders
  static Future<void> _scheduleReminders() async {
    if (!_initialized) await init();
    
    // Cancel existing reminders
    await cancelAll();
    
    final intervalHours = await getIntervalHours();
    final now = DateTime.now();
    
    // Schedule reminders throughout the day (8 AM to 10 PM)
    const startHour = 8;
    const endHour = 22;
    
    var scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      startHour,
      0,
    );
    
    // If start time has passed, schedule for tomorrow
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }
    
    int notificationId = 1000;
    
    // Schedule multiple reminders
    while (scheduledTime.hour <= endHour) {
      await _scheduleNotification(
        id: notificationId++,
        title: '💧 Time to Hydrate!',
        body: 'Drink some water to stay healthy and focused.',
        scheduledDate: scheduledTime,
      );
      
      scheduledTime = scheduledTime.add(Duration(hours: intervalHours));
    }
    
    debugPrint('💧 Scheduled water reminders every $intervalHours hours');
  }
  
  /// Schedule a single notification
  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'water_reminder_channel',
          'Water Reminders',
          channelDescription: 'Reminders to drink water',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
  
  /// Cancel all water reminders
  static Future<void> cancelAll() async {
    // Cancel notifications with IDs 1000-1100 (our water reminder range)
    for (int i = 1000; i <= 1100; i++) {
      await _notifications.cancel(i);
    }
    debugPrint('💧 Cancelled all water reminders');
  }
  
  /// Show immediate test notification
  static Future<void> showTestNotification() async {
    if (!_initialized) await init();
    
    await _notifications.show(
      999,
      '💧 Water Reminder Test',
      'This is how your water reminders will look!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'water_reminder_channel',
          'Water Reminders',
          channelDescription: 'Reminders to drink water',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}
