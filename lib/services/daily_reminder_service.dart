import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

/// Service to handle daily reading reminders and tracking
class DailyReminderService {
  static final DailyReminderService _instance = DailyReminderService._internal();
  factory DailyReminderService() => _instance;
  DailyReminderService._internal();

  // SharedPreferences keys
  static const String _keyLastReadDate = 'last_read_date';
  static const String _keyLastReadTime = 'last_read_time';
  static const String _keyDailyReadingStreak = 'daily_reading_streak';
  static const String _keyReminderEnabled = 'reminder_enabled';
  static const String _keyReminderTime = 'reminder_time'; // Format: "HH:mm" (e.g., "09:00")
  static const String _keyLastReminderShown = 'last_reminder_shown_date';

  /// Check if user has read today's content
  Future<bool> hasReadToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? lastReadDate = prefs.getString(_keyLastReadDate);
      final String today = DateTime.now().toIso8601String().split('T')[0];
      
      return lastReadDate == today;
    } catch (e) {
      return false;
    }
  }

  /// Mark today's content as read
  Future<void> markAsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String today = DateTime.now().toIso8601String().split('T')[0];
      final DateTime now = DateTime.now();
      
      // Get yesterday's date
      final String? lastReadDate = prefs.getString(_keyLastReadDate);
      final DateTime yesterday = now.subtract(const Duration(days: 1));
      final String yesterdayStr = yesterday.toIso8601String().split('T')[0];
      
      // Check if reading streak should continue
      int currentStreak = prefs.getInt(_keyDailyReadingStreak) ?? 0;
      
      if (lastReadDate == yesterdayStr) {
        // Consecutive day - increment streak
        currentStreak++;
      } else if (lastReadDate == today) {
        // Already read today - don't change streak
      } else {
        // Break in streak - reset to 1 (today)
        currentStreak = 1;
      }
      
      await prefs.setString(_keyLastReadDate, today);
      await prefs.setString(_keyLastReadTime, now.toIso8601String());
      await prefs.setInt(_keyDailyReadingStreak, currentStreak);
    } catch (e) {}
  }

  /// Get current reading streak
  Future<int> getReadingStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int streak = prefs.getInt(_keyDailyReadingStreak) ?? 0;
      
      // Verify streak is still valid
      final bool hasReadToday = await this.hasReadToday();
      if (!hasReadToday) {
        // Check if yesterday was read
        final String? lastReadDate = prefs.getString(_keyLastReadDate);
        final DateTime yesterday = DateTime.now().subtract(const Duration(days: 1));
        final String yesterdayStr = yesterday.toIso8601String().split('T')[0];
        
        if (lastReadDate != yesterdayStr) {
          // Streak broken - reset
          await prefs.setInt(_keyDailyReadingStreak, 0);
          return 0;
        }
      }
      
      return streak;
    } catch (e) {
      return 0;
    }
  }

  /// Check if reminder should be shown (not shown today yet)
  Future<bool> shouldShowReminder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool reminderEnabled = prefs.getBool(_keyReminderEnabled) ?? true;
      
      if (!reminderEnabled) {
        return false;
      }
      
      // Check if already read today
      final bool hasRead = await hasReadToday();
      if (hasRead) {
        return false;
      }
      
      // Check if reminder was already shown today
      final String? lastReminderDate = prefs.getString(_keyLastReminderShown);
      final String today = DateTime.now().toIso8601String().split('T')[0];
      
      if (lastReminderDate == today) {
        return false; // Already shown today
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Mark reminder as shown for today
  Future<void> markReminderAsShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String today = DateTime.now().toIso8601String().split('T')[0];
      await prefs.setString(_keyLastReminderShown, today);
    } catch (e) {}
  }

  /// Enable or disable reminders
  Future<void> setReminderEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyReminderEnabled, enabled);
      
      final notificationService = NotificationService();
      if (enabled) {
        // Schedule notifications if enabling (09:00, 12:00, 18:00)
        await initializeDailyReminder();
      } else {
        // Cancel all notifications if disabling
        await notificationService.cancelAllNotifications();
      }
    } catch (e) {}
  }

  /// Check if reminders are enabled
  Future<bool> isReminderEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyReminderEnabled) ?? true;
    } catch (e) {
      return true;
    }
  }

  /// Set reminder time (format: "HH:mm")
  /// Note: Schedules reminders at 09:00, 12:00, and 18:00
  Future<void> setReminderTime(String time) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyReminderTime, time);
      
      // Schedule all daily reminders (09:00, 12:00, 18:00)
      final notificationService = NotificationService();
      await notificationService.scheduleDailyReminders(null);
    } catch (e) {}
  }
  
  /// Initialize daily reminder notifications (09:00, 12:00, 18:00)
  Future<void> initializeDailyReminder() async {
    try {
      final reminderEnabled = await isReminderEnabled();
      if (reminderEnabled) {
        final notificationService = NotificationService();
        // Schedule both morning (9:00) and evening (18:00) reminders
        await notificationService.scheduleDailyReminders(null);
      }
    } catch (e) {}
  }

  /// Get reminder time (default: "09:00")
  Future<String> getReminderTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyReminderTime) ?? "09:00";
    } catch (e) {
      return "09:00";
    }
  }

  /// Get last read date
  Future<DateTime?> getLastReadDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? lastReadDate = prefs.getString(_keyLastReadDate);
      if (lastReadDate != null) {
        return DateTime.parse(lastReadDate);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get motivational message based on streak
  String getStreakMessage(int streak) {
    if (streak == 0) {
      return "Hadi bugünkü içeriği okuyarak başlayalım! 🌟";
    } else if (streak == 1) {
      return "Harika! İlk günü tamamladın! 💪";
    } else if (streak < 7) {
      return "$streak günlük okuma serisi! Devam et! 🔥";
    } else if (streak < 30) {
      return "Muhteşem! $streak gündür devam ediyorsun! 🌟";
    } else if (streak < 100) {
      return "İnanılmaz! $streak günlük seri! Sen harikasın! 🎉";
    } else {
      return "Efsane! $streak günlük okuma serisi! Mükemmel! 👑";
    }
  }

  /// Get reminder message
  String getReminderMessage(String itemType) {
    switch (itemType.toLowerCase()) {
      case 'dua':
        return "Bugünkü duayı okudun mu? 🤲";
      case 'hadith':
        return "Bugünkü hadisi okudun mu? 📖";
      case 'ayah':
        return "Bugünkü ayeti okudun mu? ✨";
      default:
        return "Bugünkü içeriği okudun mu? 📝";
    }
  }
}

