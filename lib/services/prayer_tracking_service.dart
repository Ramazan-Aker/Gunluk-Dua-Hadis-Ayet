import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/prayer_tracking.dart';

class PrayerTrackingService {
  static const _historyKey = 'prayer_tracking_history_v1';
  static const _goalKey = 'prayer_tracking_default_goal_v1';
  static const _defaultGoal = 5;
  static const _historyRetentionDays = 400;

  Future<PrayerTrackingSummary> loadSummary({DateTime? now}) async {
    final today = _dateOnly(now ?? DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    final defaultGoal = _validatedGoal(prefs.getInt(_goalKey));
    final history = _readHistory(prefs, defaultGoal);
    final todayEntry = history[today] ?? _emptyDay(today, defaultGoal);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final week = List.generate(7, (index) {
      final date = weekStart.add(Duration(days: index));
      return history[date] ?? _emptyDay(date, defaultGoal);
    });

    return PrayerTrackingSummary(
      today: todayEntry,
      week: week,
      currentStreak: _currentStreak(history, today, defaultGoal),
      longestStreak: _longestStreak(history),
      defaultGoal: defaultGoal,
    );
  }

  Future<List<PrayerTrackingDay>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final defaultGoal = _validatedGoal(prefs.getInt(_goalKey));
    final history = _readHistory(prefs, defaultGoal).values.toList()
      ..sort((first, second) => first.date.compareTo(second.date));
    return history;
  }

  Future<PrayerTrackingSummary> togglePrayer(
    TrackedPrayer prayer, {
    DateTime? now,
  }) async {
    final today = _dateOnly(now ?? DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    final defaultGoal = _validatedGoal(prefs.getInt(_goalKey));
    final history = _readHistory(prefs, defaultGoal);
    final existing = history[today] ?? _emptyDay(today, defaultGoal);
    final completed = Set<TrackedPrayer>.from(existing.completed);
    completed.contains(prayer)
        ? completed.remove(prayer)
        : completed.add(prayer);
    history[today] = existing.copyWith(
      completed: completed,
      isPaused: false,
    );
    await _writeHistory(prefs, history, today);
    return loadSummary(now: today);
  }

  Future<PrayerTrackingSummary> setDefaultGoal(
    int goal, {
    DateTime? now,
  }) async {
    if (!PrayerTrackingSummary.allowedGoals.contains(goal)) {
      throw ArgumentError.value(goal, 'goal', 'Hedef 1, 3 veya 5 olmalı');
    }
    final today = _dateOnly(now ?? DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    final oldGoal = _validatedGoal(prefs.getInt(_goalKey));
    final history = _readHistory(prefs, oldGoal);
    final existing = history[today] ?? _emptyDay(today, oldGoal);
    history[today] = existing.copyWith(goal: goal);
    await prefs.setInt(_goalKey, goal);
    await _writeHistory(prefs, history, today);
    return loadSummary(now: today);
  }

  Future<PrayerTrackingSummary> setTodayPaused(
    bool paused, {
    DateTime? now,
  }) async {
    final today = _dateOnly(now ?? DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    final defaultGoal = _validatedGoal(prefs.getInt(_goalKey));
    final history = _readHistory(prefs, defaultGoal);
    final existing = history[today] ?? _emptyDay(today, defaultGoal);
    history[today] = existing.copyWith(isPaused: paused);
    await _writeHistory(prefs, history, today);
    return loadSummary(now: today);
  }

  Map<DateTime, PrayerTrackingDay> _readHistory(
    SharedPreferences prefs,
    int defaultGoal,
  ) {
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final result = <DateTime, PrayerTrackingDay>{};
      for (final entry in decoded.entries) {
        final date = DateTime.tryParse(entry.key);
        final value = entry.value;
        if (date == null || value is! Map<String, dynamic>) continue;
        final normalized = _dateOnly(date);
        result[normalized] = PrayerTrackingDay.fromJson(
          normalized,
          value,
          defaultGoal,
        );
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeHistory(
    SharedPreferences prefs,
    Map<DateTime, PrayerTrackingDay> history,
    DateTime today,
  ) async {
    final oldestAllowed =
        today.subtract(const Duration(days: _historyRetentionDays));
    history.removeWhere((date, _) => date.isBefore(oldestAllowed));
    final encoded = <String, dynamic>{
      for (final entry in history.entries)
        _dateKey(entry.key): entry.value.toJson(),
    };
    await prefs.setString(_historyKey, jsonEncode(encoded));
  }

  int _currentStreak(
    Map<DateTime, PrayerTrackingDay> history,
    DateTime today,
    int defaultGoal,
  ) {
    var streak = 0;
    var cursor = today;
    var checked = 0;
    while (checked <= _historyRetentionDays) {
      final day = history[cursor] ?? _emptyDay(cursor, defaultGoal);
      if (day.isPaused) {
        cursor = cursor.subtract(const Duration(days: 1));
        checked++;
        continue;
      }
      if (day.goalMet) {
        streak++;
      } else if (cursor == today) {
        // Bugün henüz bitmedi; dünkü seri korunur.
      } else {
        break;
      }
      cursor = cursor.subtract(const Duration(days: 1));
      checked++;
    }
    return streak;
  }

  int _longestStreak(Map<DateTime, PrayerTrackingDay> history) {
    if (history.isEmpty) return 0;
    final dates = history.keys.toList()..sort();
    var longest = 0;
    var current = 0;
    var cursor = dates.first;
    final lastDate = dates.last;
    while (!cursor.isAfter(lastDate)) {
      final day = history[cursor];
      if (day?.isPaused == true) {
        cursor = cursor.add(const Duration(days: 1));
        continue;
      }
      if (day == null || !day.goalMet) {
        current = 0;
      } else {
        current++;
        if (current > longest) longest = current;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return longest;
  }

  static PrayerTrackingDay _emptyDay(DateTime date, int goal) {
    return PrayerTrackingDay(
      date: date,
      completed: const <TrackedPrayer>{},
      goal: goal,
    );
  }

  static int _validatedGoal(int? goal) =>
      PrayerTrackingSummary.allowedGoals.contains(goal) ? goal! : _defaultGoal;

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
