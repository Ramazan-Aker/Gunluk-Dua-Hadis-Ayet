import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to handle local notifications for daily reminders
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  static const MethodChannel _channel = MethodChannel('com.tahram.gunlukduahadis/notification');

  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize timezone
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

      // Android initialization settings
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      // Initialization settings
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // Initialize plugin
      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Don't request permission here - we'll request after showing value proposition dialog
      // in HomeScreen._setupNotificationsAndPermissions for better opt-in rate

      _isInitialized = true;
    } catch (e) {
      // Init failed
    }
  }

  /// Request notification permission (Android 13+ / iOS)
  /// Call this after showing value proposition to user for better opt-in rate
  Future<bool> requestPermission() async {
    if (!_isInitialized) {
      await initialize();
    }
    if (Platform.isAndroid) {
      final androidImplementation = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final bool? granted = await androidImplementation.requestNotificationsPermission();
        return granted ?? false;
      }
    }
    return true; // iOS handles in DarwinInitializationSettings
  }
  
  /// Check and request exact alarm permission with user dialog
  Future<bool> checkAndRequestExactAlarmPermission(BuildContext? context) async {
    if (Platform.isAndroid) {
      final androidImplementation = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        // Check if exact alarm permission is granted
        final bool? canScheduleExactAlarms = await androidImplementation.canScheduleExactNotifications();
        
        // Don't show dialog to user - just return the status
        // If not granted, we'll use inexact mode which is good enough for daily reminders
        if (canScheduleExactAlarms == false) {
          return false;
        }
        return canScheduleExactAlarms ?? false;
      }
    }
    return true; // iOS or permission granted
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // You can add navigation logic here if needed
  }

  /// Schedule daily reminder notification
  Future<bool> scheduleDailyReminder({
    required int hour,
    required int minute,
    String? customMessage,
    BuildContext? context,
    int notificationId = 0,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Check if notifications are enabled
      final bool notificationsEnabled = await areNotificationsEnabled();
      if (!notificationsEnabled) return false;

      // Check exact alarm permission for Android 12+ and determine schedule mode
      AndroidScheduleMode scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
      
      if (Platform.isAndroid) {
        final bool hasPermission = await checkAndRequestExactAlarmPermission(context);
        if (!hasPermission) {
          scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
        }
      }

      // Schedule new notification with appropriate schedule mode
      await _notifications.zonedSchedule(
        notificationId, // Notification ID
        'Her Gün İslam',
        customMessage ?? 'Bugünkü duayı, hadisi veya ayeti okudun mu? 🤲',
        _nextInstanceOfTime(hour, minute),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminder',
            'Her Gün İslam Hatırlatmaları',
            channelDescription: 'Her gün günlük dua, hadis veya ayet için hatırlatmalar',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            enableVibration: true,
            playSound: true,
            channelShowBadge: true,
            visibility: NotificationVisibility.public,
            autoCancel: false,
            ongoing: false,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Schedule multiple daily reminders (09:00, 12:00, 18:00)
  Future<bool> scheduleDailyReminders(BuildContext? context) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Check if notifications are enabled
      final bool notificationsEnabled = await areNotificationsEnabled();
      if (!notificationsEnabled) return false;

      if (Platform.isAndroid) {
        await checkAndRequestExactAlarmPermission(context);
      }

      // Cancel existing notifications first
      await cancelAllNotifications();

      // Schedule morning notification (9:00 AM)
      final morningSuccess = await scheduleDailyReminder(
        hour: 9,
        minute: 0,
        customMessage: 'Günaydın! Bugünkü duayı, hadisi veya ayeti okudun mu? 🌅',
        context: context,
        notificationId: 0,
      );

      // Schedule midday notification (12:00) - extra engagement
      final middaySuccess = await scheduleDailyReminder(
        hour: 12,
        minute: 0,
        customMessage: 'Öğle molası! Bugünkü içeriği okumayı unutma 📖',
        context: context,
        notificationId: 1,
      );

      // Schedule evening notification (6:00 PM / 18:00)
      final eveningSuccess = await scheduleDailyReminder(
        hour: 18,
        minute: 0,
        customMessage: 'İyi akşamlar! Bugünkü duayı, hadisi veya ayeti okumayı unutma! 🌙',
        context: context,
        notificationId: 2,
      );

      return morningSuccess && middaySuccess && eveningSuccess;
    } catch (e) {
      return false;
    }
  }

  /// Get next instance of the specified time
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If the time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  /// Show immediate notification (for testing)
  Future<void> showNotification({
    String title = 'Her Gün İslam',
    String body = 'Bugünkü içeriği okumayı unutma!',
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      await _notifications.show(
        999, // Unique ID for immediate notifications
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminder',
            'Her Gün İslam Hatırlatmaları',
            channelDescription: 'Her gün günlük dua, hadis veya ayet için hatırlatmalar',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            enableVibration: true,
            playSound: true,
            channelShowBadge: true,
            visibility: NotificationVisibility.public,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Show test notification after 5 seconds (for testing delayed notifications)
  Future<void> showTestNotificationAfter5Seconds() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final scheduledTime = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));
      
      await _notifications.zonedSchedule(
        998, // Unique ID for test notifications
        'Test Bildirimi',
        '5 saniye sonra gelen test bildirimi! 🎉',
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminder',
            'Her Gün İslam Hatırlatmaları',
            channelDescription: 'Her gün günlük dua, hadis veya ayet için hatırlatmalar',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            enableVibration: true,
            playSound: true,
            channelShowBadge: true,
            visibility: NotificationVisibility.public,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
    } catch (e) {
      // Ignore
    }
  }

  /// Cancel specific notification
  Future<void> cancelNotification(int id) async {
    try {
      await _notifications.cancel(id);
    } catch (e) {
      // Ignore
    }
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final androidImplementation = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        return await androidImplementation.areNotificationsEnabled() ?? false;
      }
    }
    // For iOS, assume enabled if no error
    return true;
  }
  
  /// Check if app should reschedule notifications (after boot)
  Future<bool> shouldRescheduleNotifications() async {
    if (Platform.isAndroid) {
      try {
        final bool? shouldReschedule = await _channel.invokeMethod<bool>('shouldRescheduleNotifications');
        return shouldReschedule ?? false;
      } catch (e) {
        return false;
      }
    }
    return false;
  }
  
  /// Check and request battery optimization exemption
  /// This helps ensure notifications work reliably even when app is in background
  Future<void> requestBatteryOptimizationExemption(BuildContext? context) async {
    if (Platform.isAndroid) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final bool hasAskedBefore = prefs.getBool('battery_optimization_asked') ?? false;
        
        if (!hasAskedBefore && context != null && context.mounted) {
          final bool? userAccepted = await showDialog<bool>(
            context: context,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                title: const Text('Bildirimler İçin Önemli'),
                content: const Text(
                  'Bildirimlerin düzenli çalışması için batarya optimizasyonlarından muaf tutulmalıyız.\n\n'
                  'Bu, bildirimlerin her zaman zamanında gelmesini sağlar.\n\n'
                  'Ayarlara gitmek ister misiniz?'
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Şimdi Değil'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('Ayarlara Git'),
                  ),
                ],
              );
            },
          );
          
          await prefs.setBool('battery_optimization_asked', true);
          
          if (userAccepted == true) {
            // Open battery optimization settings
            const platform = MethodChannel('com.tahram.gunlukduahadis/battery');
            try {
              await platform.invokeMethod('openBatterySettings');
            } catch (e) {
              // Ignore
            }
          }
        }
      } catch (e) {
        // Ignore
      }
    }
  }
  
  /// Get list of pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _notifications.pendingNotificationRequests();
    } catch (e) {
      return [];
    }
  }
}

