import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/smart_goal_reminder.dart';
import 'daily_spiritual_plan_service.dart';
import 'dhikr_tracking_service.dart';
import 'notification_service.dart';
import 'prayer_tracking_service.dart';
import 'quran_reading_plan_service.dart';

class SmartGoalReminderService {
  static const _settingsKey = 'smart_goal_reminder_settings_v1';
  static const _firstNotificationId = 20000;

  final NotificationService _notifications = NotificationService();

  Future<List<SmartGoalReminderSetting>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null || raw.isEmpty) return _defaults;
    try {
      final decoded = (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(SmartGoalReminderSetting.fromJson)
          .toList();
      return [
        for (final fallback in _defaults)
          decoded.where((item) => item.type == fallback.type).firstOrNull ??
              fallback,
      ];
    } catch (_) {
      return _defaults;
    }
  }

  Future<List<SmartGoalReminderSetting>> updateSetting(
    SmartGoalReminderSetting setting,
  ) async {
    final settings = await loadSettings();
    final updated = [
      for (final item in settings)
        if (item.type == setting.type) setting else item,
    ];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _settingsKey,
      jsonEncode(updated.map((item) => item.toJson()).toList()),
    );
    await refreshSchedule();
    return updated;
  }

  Future<int> refreshSchedule({DateTime? now}) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return 0;
    final current = now ?? DateTime.now();
    final settings = await loadSettings();
    await cancelAll();
    if (!settings.any((setting) => setting.enabled)) return 0;
    if (!await _notifications.areNotificationsEnabled()) return 0;

    final prayer = await PrayerTrackingService().loadSummary(now: current);
    final dhikr = await DhikrTrackingService().loadSummary(
      now: current,
      forceReload: true,
    );
    final quran = await QuranReadingPlanService().loadSummary(now: current);
    final daily = await DailySpiritualPlanService().loadSummary(now: current);
    var scheduled = 0;

    for (final setting in settings.where((item) => item.enabled)) {
      final completedToday = switch (setting.type) {
        SmartGoalType.prayer => prayer.today.goalMet,
        SmartGoalType.dhikr => dhikr.count >= dhikr.target,
        SmartGoalType.quran => quran == null ||
            quran.isComplete ||
            (quran.todayTarget > 0 &&
                quran.completedToday >= quran.todayTarget),
        SmartGoalType.dailyPlan => daily.completed,
      };
      final scheduledAt = nextReminderAt(
        setting: setting,
        now: current,
        completedToday: completedToday,
      );
      if (setting.type == SmartGoalType.quran && quran == null) continue;

      final body = scheduledAt.day == current.day &&
              scheduledAt.month == current.month &&
              scheduledAt.year == current.year
          ? switch (setting.type) {
              SmartGoalType.prayer =>
                'Bugünkü namaz hedefinde ${prayer.today.completedCount}/${prayer.today.goal} vakit tamamlandı.',
              SmartGoalType.dhikr =>
                '${dhikr.option.title} hedefinde ${dhikr.count}/${dhikr.target} tamamlandı.',
              SmartGoalType.quran =>
                'Bugünkü hatim hedefinde ${quran!.completedToday}/${quran.todayTarget} cüz tamamlandı.',
              SmartGoalType.dailyPlan =>
                'Günlük planında ${daily.tasks.length - daily.completedCount} hedef kaldı.',
            }
          : _tomorrowMessage(setting.type);

      final success = await _notifications.scheduleSmartGoalNotification(
        id: _notificationId(setting.type),
        title: setting.type.title,
        body: body,
        scheduledAt: scheduledAt,
      );
      if (success) scheduled++;
    }
    return scheduled;
  }

  Future<void> cancelAll() async {
    for (final type in SmartGoalType.values) {
      await _notifications.cancelNotification(_notificationId(type));
    }
  }

  static int _notificationId(SmartGoalType type) =>
      _firstNotificationId + type.index;

  static DateTime nextReminderAt({
    required SmartGoalReminderSetting setting,
    required DateTime now,
    required bool completedToday,
  }) {
    var scheduledAt = DateTime(
      now.year,
      now.month,
      now.day,
      setting.hour,
      setting.minute,
    );
    if (!scheduledAt.isAfter(now) || completedToday) {
      scheduledAt = scheduledAt.add(const Duration(days: 1));
    }
    return scheduledAt;
  }

  static String _tomorrowMessage(SmartGoalType type) => switch (type) {
        SmartGoalType.prayer => 'Yarınki namaz hedefini takip etmeyi unutma.',
        SmartGoalType.dhikr => 'Yarınki zikir hedefin seni bekliyor.',
        SmartGoalType.quran => 'Hatim planındaki günlük cüz hedefini takip et.',
        SmartGoalType.dailyPlan => 'Yarınki manevi planını tamamlamayı unutma.',
      };

  static const _defaults = <SmartGoalReminderSetting>[
    SmartGoalReminderSetting(
      type: SmartGoalType.prayer,
      enabled: false,
      hour: 21,
      minute: 0,
    ),
    SmartGoalReminderSetting(
      type: SmartGoalType.dhikr,
      enabled: false,
      hour: 20,
      minute: 30,
    ),
    SmartGoalReminderSetting(
      type: SmartGoalType.quran,
      enabled: false,
      hour: 20,
      minute: 0,
    ),
    SmartGoalReminderSetting(
      type: SmartGoalType.dailyPlan,
      enabled: false,
      hour: 21,
      minute: 30,
    ),
  ];
}
