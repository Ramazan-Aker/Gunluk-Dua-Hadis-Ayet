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

      // Request permissions for Android 13+
      if (Platform.isAndroid) {
        await _requestAndroidPermissions();
      }

      _isInitialized = true;
      print('✅ Notification service initialized');
    } catch (e) {
      print('❌ Error initializing notification service: $e');
    }
  }

  /// Request Android permissions (Android 13+)
  Future<void> _requestAndroidPermissions() async {
    if (Platform.isAndroid) {
      final androidImplementation = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        // Request notification permission
        final bool? granted = await androidImplementation.requestNotificationsPermission();
        print('📱 Notification permission granted: $granted');
        
        // Request exact alarm permission (required for scheduled notifications on Android 12+)
        final bool? exactAlarmGranted = await androidImplementation.requestExactAlarmsPermission();
        print('⏰ Exact alarm permission granted: $exactAlarmGranted');
      }
    }
  }
  
  /// Check and request exact alarm permission with user dialog
  Future<bool> checkAndRequestExactAlarmPermission(BuildContext? context) async {
    if (Platform.isAndroid) {
      final androidImplementation = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        // Check if exact alarm permission is granted
        final bool? canScheduleExactAlarms = await androidImplementation.canScheduleExactNotifications();
        
        if (canScheduleExactAlarms == false) {
          // Show dialog explaining why we need this permission
          if (context != null && context.mounted) {
            final bool? userAccepted = await showDialog<bool>(
              context: context,
              builder: (BuildContext dialogContext) {
                return AlertDialog(
                  title: const Text('Bildirim İzni Gerekli'),
                  content: const Text(
                    'Günlük hatırlatmalar için "Tam Zamanlı Alarmlar ve Bildirimler" iznine ihtiyacımız var.\n\n'
                    'Bu izni ayarlardan verebilirsiniz. Şimdi ayarlara gitmek ister misiniz?'
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('İptal'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text('Ayarlara Git'),
                    ),
                  ],
                );
              },
            );
            
            if (userAccepted == true) {
              // Request exact alarm permission (this will open system settings)
              await androidImplementation.requestExactAlarmsPermission();
              
              // Check again after user returns
              await Future.delayed(const Duration(seconds: 1));
              final bool? recheckPermission = await androidImplementation.canScheduleExactNotifications();
              return recheckPermission ?? false;
            }
          } else {
            // No context, just request permission
            await androidImplementation.requestExactAlarmsPermission();
          }
          return false;
        }
        return canScheduleExactAlarms ?? false;
      }
    }
    return true; // iOS or permission granted
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('📱 Notification tapped: ${response.payload}');
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
      if (!notificationsEnabled) {
        print('⚠️ Notifications are not enabled');
        return false;
      }

      // Check exact alarm permission for Android 12+ and determine schedule mode
      AndroidScheduleMode scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
      
      if (Platform.isAndroid) {
        final bool hasPermission = await checkAndRequestExactAlarmPermission(context);
        if (!hasPermission) {
          print('⚠️ Exact alarm permission not granted, using inexact schedule mode as fallback');
          scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
        } else {
          print('✅ Exact alarm permission granted, using exact schedule mode');
        }
      }

      // Schedule new notification with appropriate schedule mode
      await _notifications.zonedSchedule(
        notificationId, // Notification ID
        'Günlük Dua & Hadis',
        customMessage ?? 'Bugünkü duayı, hadisi veya ayeti okudun mu? 🤲',
        _nextInstanceOfTime(hour, minute),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminder',
            'Günlük Hatırlatmalar',
            channelDescription: 'Her gün günlük dua, hadis veya ayet için hatırlatmalar',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            enableVibration: true,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      print('✅ Daily reminder scheduled for $hour:$minute (ID: $notificationId, Mode: $scheduleMode)');
      return true;
    } catch (e) {
      print('❌ Error scheduling daily reminder: $e');
      return false;
    }
  }

  /// Schedule multiple daily reminders (morning and evening)
  Future<bool> scheduleDailyReminders(BuildContext? context) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Check if notifications are enabled
      final bool notificationsEnabled = await areNotificationsEnabled();
      if (!notificationsEnabled) {
        print('⚠️ Notifications are not enabled');
        return false;
      }

      // Check exact alarm permission for Android 12+ (but don't block if not granted)
      if (Platform.isAndroid) {
        final bool hasPermission = await checkAndRequestExactAlarmPermission(context);
        if (!hasPermission) {
          print('⚠️ Exact alarm permission not granted, will use inexact schedule mode');
        } else {
          print('✅ Exact alarm permission granted');
        }
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

      // Schedule evening notification (6:00 PM / 18:00)
      final eveningSuccess = await scheduleDailyReminder(
        hour: 18,
        minute: 0,
        customMessage: 'İyi akşamlar! Bugünkü duayı, hadisi veya ayeti okumayı unutma! 🌙',
        context: context,
        notificationId: 1,
      );

      if (morningSuccess && eveningSuccess) {
        print('✅ Both daily reminders scheduled successfully');
        return true;
      } else {
        print('⚠️ Some reminders could not be scheduled');
        return false;
      }
    } catch (e) {
      print('❌ Error scheduling daily reminders: $e');
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
    String title = 'Günlük Dua & Hadis',
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
            'Günlük Hatırlatmalar',
            channelDescription: 'Her gün günlük dua, hadis veya ayet için hatırlatmalar',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            enableVibration: true,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    } catch (e) {
      print('❌ Error showing notification: $e');
    }
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      print('✅ All notifications cancelled');
    } catch (e) {
      print('❌ Error cancelling notifications: $e');
    }
  }

  /// Cancel specific notification
  Future<void> cancelNotification(int id) async {
    try {
      await _notifications.cancel(id);
    } catch (e) {
      print('❌ Error cancelling notification $id: $e');
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
        print('❌ Error checking shouldRescheduleNotifications: $e');
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
              print('❌ Error opening battery settings: $e');
            }
          }
        }
      } catch (e) {
        print('❌ Error requesting battery optimization exemption: $e');
      }
    }
  }
  
  /// Get list of pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _notifications.pendingNotificationRequests();
    } catch (e) {
      print('❌ Error getting pending notifications: $e');
      return [];
    }
  }
}

