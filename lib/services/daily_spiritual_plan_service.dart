import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_spiritual_plan.dart';
import 'dhikr_tracking_service.dart';
import 'prayer_tracking_service.dart';
import 'quran_reading_plan_service.dart';

class DailySpiritualPlanService {
  DailySpiritualPlanService({
    PrayerTrackingService? prayerService,
    DhikrTrackingService? dhikrService,
    QuranReadingPlanService? quranPlanService,
  })  : _prayerService = prayerService ?? PrayerTrackingService(),
        _dhikrService = dhikrService ?? DhikrTrackingService(),
        _quranPlanService = quranPlanService ?? QuranReadingPlanService();

  static const dailyContentId = 'daily_content';
  static const prayerId = 'prayer';
  static const dhikrId = 'dhikr';
  static const quranId = 'quran';
  static const coreTaskIds = <String>{
    dailyContentId,
    prayerId,
    dhikrId,
    quranId,
  };

  static const _customTasksKey = 'daily_spiritual_plan_custom_tasks_v1';
  static const _manualHistoryKey = 'daily_spiritual_plan_manual_history_v1';
  static const _achievementsKey = 'daily_spiritual_plan_achievements_v1';
  static const _enabledCoreKey = 'daily_spiritual_plan_enabled_core_v1';
  static const _retentionDays = 400;

  final PrayerTrackingService _prayerService;
  final DhikrTrackingService _dhikrService;
  final QuranReadingPlanService _quranPlanService;

  Future<DailySpiritualPlanSummary> loadSummary({DateTime? now}) async {
    final today = _dateOnly(now ?? DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    final enabled = _enabledCoreIds(prefs);
    final customTasks = _readCustomTasks(prefs);
    final manualHistory = _readManualHistory(prefs);
    final todayManual = manualHistory[today] ?? const <String>{};

    final prayer = await _prayerService.loadSummary(now: today);
    final dhikr = await _dhikrService.loadSummary(
      now: today,
      forceReload: true,
    );
    final quran = await _quranPlanService.loadSummary(now: today);
    final tasks = <DailyPlanTaskStatus>[];

    if (enabled.contains(dailyContentId)) {
      final hasRead = prefs.getString('last_read_date') == _dateKey(today);
      tasks.add(
        DailyPlanTaskStatus(
          id: dailyContentId,
          type: DailyPlanTaskType.dailyContent,
          title: 'Günün içeriğini oku',
          subtitle: hasRead
              ? 'Bugünün ayet, dua veya hadisi okundu'
              : 'Ayet, dua veya hadis seni bekliyor',
          progress: hasRead ? 1 : 0,
          completed: hasRead,
        ),
      );
    }
    if (enabled.contains(prayerId)) {
      tasks.add(
        DailyPlanTaskStatus(
          id: prayerId,
          type: DailyPlanTaskType.prayer,
          title: 'Namaz hedefi',
          subtitle:
              '${prayer.today.completedCount}/${prayer.today.goal} vakit tamamlandı',
          progress: prayer.today.progress,
          completed: prayer.today.goalMet,
        ),
      );
    }
    if (enabled.contains(dhikrId)) {
      tasks.add(
        DailyPlanTaskStatus(
          id: dhikrId,
          type: DailyPlanTaskType.dhikr,
          title: 'Zikir hedefi',
          subtitle: '${dhikr.count}/${dhikr.target} ${dhikr.option.title}',
          progress: dhikr.progress,
          completed: dhikr.count >= dhikr.target,
        ),
      );
    }
    if (enabled.contains(quranId) && quran != null) {
      final target = quran.todayTarget;
      final completedToday = quran.completedTodayForPlan;
      final complete =
          quran.isComplete || target == 0 || completedToday >= target;
      tasks.add(
        DailyPlanTaskStatus(
          id: quranId,
          type: DailyPlanTaskType.quran,
          title: 'Hatim planı',
          subtitle: quran.isComplete
              ? 'Hatim planı tamamlandı'
              : target == 0
                  ? 'Bugün için yeni cüz hedefi yok'
                  : '$completedToday/$target cüz bugün okundu',
          progress: quran.isComplete
              ? 1
              : target == 0
                  ? 1
                  : (completedToday / target).clamp(0, 1),
          completed: complete,
        ),
      );
    }
    for (final custom in customTasks) {
      final complete = todayManual.contains(custom.id);
      tasks.add(
        DailyPlanTaskStatus(
          id: custom.id,
          type: DailyPlanTaskType.custom,
          title: custom.title,
          subtitle: complete ? 'Bugün tamamlandı' : 'Kişisel günlük hedef',
          progress: complete ? 1 : 0,
          completed: complete,
          customTask: custom,
        ),
      );
    }

    final achievements = _readAchievements(prefs);
    if (tasks.isNotEmpty && tasks.every((task) => task.completed)) {
      achievements.add(today);
      await _writeAchievements(prefs, achievements, today);
    }
    final streaks = _streaks(achievements, today);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final week = List.generate(7, (index) {
      final date = weekStart.add(Duration(days: index));
      return DailyPlanWeekDay(
          date: date, completed: achievements.contains(date));
    });

    return DailySpiritualPlanSummary(
      date: today,
      tasks: tasks,
      currentStreak: streaks.$1,
      longestStreak: streaks.$2,
      week: week,
      enabledCoreTaskIds: enabled,
    );
  }

  Future<Set<DateTime>> achievementDates() async {
    final prefs = await SharedPreferences.getInstance();
    return _readAchievements(prefs);
  }

  Future<DailySpiritualPlanSummary> toggleCustomTask(
    String taskId, {
    DateTime? now,
  }) async {
    final today = _dateOnly(now ?? DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    final tasks = _readCustomTasks(prefs);
    if (!tasks.any((task) => task.id == taskId)) {
      throw ArgumentError.value(taskId, 'taskId', 'Kişisel hedef bulunamadı');
    }
    final history = _readManualHistory(prefs);
    final completed = Set<String>.from(history[today] ?? const <String>{});
    completed.contains(taskId)
        ? completed.remove(taskId)
        : completed.add(taskId);
    history[today] = completed;
    await _writeManualHistory(prefs, history, today);
    return loadSummary(now: today);
  }

  Future<DailySpiritualPlanSummary> addCustomTask(
    String title, {
    DateTime? now,
  }) async {
    final normalized = title.trim();
    if (normalized.isEmpty || normalized.length > 60) {
      throw ArgumentError.value(title, 'title', 'Hedef 1-60 karakter olmalı');
    }
    final date = now ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final tasks = _readCustomTasks(prefs);
    if (tasks.length >= 8) {
      throw StateError('En fazla 8 kişisel hedef eklenebilir');
    }
    var suffix = tasks.length;
    var taskId = 'custom_${date.microsecondsSinceEpoch}_$suffix';
    while (tasks.any((task) => task.id == taskId)) {
      suffix++;
      taskId = 'custom_${date.microsecondsSinceEpoch}_$suffix';
    }
    tasks.add(
      DailyPlanCustomTask(
        id: taskId,
        title: normalized,
        createdAt: date,
      ),
    );
    await prefs.setString(
      _customTasksKey,
      jsonEncode(tasks.map((task) => task.toJson()).toList()),
    );
    return loadSummary(now: date);
  }

  Future<DailySpiritualPlanSummary> deleteCustomTask(
    String taskId, {
    DateTime? now,
  }) async {
    final date = now ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final tasks = _readCustomTasks(prefs)
      ..removeWhere((task) => task.id == taskId);
    await prefs.setString(
      _customTasksKey,
      jsonEncode(tasks.map((task) => task.toJson()).toList()),
    );
    return loadSummary(now: date);
  }

  Future<DailySpiritualPlanSummary> setCoreTaskEnabled(
    String taskId,
    bool enabled, {
    DateTime? now,
  }) async {
    if (!coreTaskIds.contains(taskId)) {
      throw ArgumentError.value(taskId, 'taskId', 'Temel hedef bulunamadı');
    }
    final prefs = await SharedPreferences.getInstance();
    final values = _enabledCoreIds(prefs);
    enabled ? values.add(taskId) : values.remove(taskId);
    await prefs.setStringList(_enabledCoreKey, values.toList()..sort());
    return loadSummary(now: now);
  }

  Set<String> _enabledCoreIds(SharedPreferences prefs) {
    final stored = prefs.getStringList(_enabledCoreKey);
    if (stored == null) return Set<String>.from(coreTaskIds);
    return stored.where(coreTaskIds.contains).toSet();
  }

  List<DailyPlanCustomTask> _readCustomTasks(SharedPreferences prefs) {
    final raw = prefs.getString(_customTasksKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(DailyPlanCustomTask.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Map<DateTime, Set<String>> _readManualHistory(SharedPreferences prefs) {
    final raw = prefs.getString(_manualHistoryKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in decoded.entries)
          if (DateTime.tryParse(entry.key) case final date?)
            _dateOnly(date):
                (entry.value as List<dynamic>).whereType<String>().toSet(),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeManualHistory(
    SharedPreferences prefs,
    Map<DateTime, Set<String>> history,
    DateTime today,
  ) async {
    final oldest = today.subtract(const Duration(days: _retentionDays));
    history.removeWhere((date, _) => date.isBefore(oldest));
    await prefs.setString(
      _manualHistoryKey,
      jsonEncode({
        for (final entry in history.entries)
          _dateKey(entry.key): entry.value.toList(),
      }),
    );
  }

  Set<DateTime> _readAchievements(SharedPreferences prefs) =>
      (prefs.getStringList(_achievementsKey) ?? const <String>[])
          .map(DateTime.tryParse)
          .whereType<DateTime>()
          .map(_dateOnly)
          .toSet();

  Future<void> _writeAchievements(
    SharedPreferences prefs,
    Set<DateTime> achievements,
    DateTime today,
  ) async {
    final oldest = today.subtract(const Duration(days: _retentionDays));
    achievements.removeWhere((date) => date.isBefore(oldest));
    final sorted = achievements.toList()..sort();
    await prefs.setStringList(
      _achievementsKey,
      sorted.map(_dateKey).toList(),
    );
  }

  (int, int) _streaks(Set<DateTime> achievements, DateTime today) {
    var current = 0;
    var cursor = today;
    for (var checked = 0; checked <= _retentionDays; checked++) {
      if (achievements.contains(cursor)) {
        current++;
      } else if (cursor != today) {
        break;
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }
    if (achievements.isEmpty) return (current, 0);
    final sorted = achievements.toList()..sort();
    var longest = 0;
    var running = 0;
    DateTime? previous;
    for (final date in sorted) {
      running = previous != null && date.difference(previous).inDays == 1
          ? running + 1
          : 1;
      longest = math.max(longest, running);
      previous = date;
    }
    return (current, longest);
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
