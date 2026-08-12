import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../models/quran_reading_plan.dart';
import 'quran_progress_service.dart';

class QuranReadingPlanService {
  QuranReadingPlanService({QuranProgressService? progressService})
      : _progress = progressService ?? QuranProgressService();

  static const _planKey = 'quran_reading_plan_v1';
  final QuranProgressService _progress;

  Future<QuranReadingPlanSummary?> loadSummary({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_planKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final plan = QuranReadingPlan.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      final today = _dateOnly(now ?? DateTime.now());
      final completed = await _progress.completedJuz();
      final dates = await _progress.completionDates();
      final streaks = _streaks(dates.values, today);
      return QuranReadingPlanSummary(
        plan: plan,
        completedJuz: completed,
        completionDates: dates,
        today: today,
        currentStreak: streaks.$1,
        longestStreak: streaks.$2,
      );
    } catch (_) {
      return null;
    }
  }

  Future<QuranReadingPlanSummary> createPlan({
    required DateTime targetDate,
    DateTime? now,
    bool resetProgress = false,
  }) async {
    final today = _dateOnly(now ?? DateTime.now());
    final target = _dateOnly(targetDate);
    if (target.isBefore(today)) {
      throw ArgumentError.value(
          targetDate, 'targetDate', 'Bitiş tarihi geçmiş olamaz');
    }
    if (resetProgress) await _progress.clearProgress();
    final completed = await _progress.completedJuz();
    final plan = QuranReadingPlan(
      startedAt: today,
      targetDate: target,
      startingCompletedCount: completed.length,
    );
    await _save(plan);
    return (await loadSummary(now: today))!;
  }

  Future<QuranReadingPlanSummary> updateTargetDate(
    DateTime targetDate, {
    DateTime? now,
  }) async {
    final summary = await loadSummary(now: now);
    if (summary == null) throw StateError('Aktif hatim planı yok');
    final today = _dateOnly(now ?? DateTime.now());
    final target = _dateOnly(targetDate);
    if (target.isBefore(today)) {
      throw ArgumentError.value(
          targetDate, 'targetDate', 'Bitiş tarihi geçmiş olamaz');
    }
    final updated = QuranReadingPlan(
      startedAt: summary.plan.startedAt,
      targetDate: target,
      startingCompletedCount: summary.plan.startingCompletedCount,
    );
    await _save(updated);
    return (await loadSummary(now: today))!;
  }

  Future<void> deletePlan() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_planKey);
  }

  Future<void> _save(QuranReadingPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_planKey, jsonEncode(plan.toJson()));
  }

  (int, int) _streaks(Iterable<DateTime> completionDates, DateTime today) {
    final readingDays = completionDates.map(_dateOnly).toSet();
    var current = 0;
    var cursor = today;
    for (var checked = 0; checked <= 400; checked++) {
      if (readingDays.contains(cursor)) {
        current++;
      } else if (cursor != today) {
        break;
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }
    if (readingDays.isEmpty) return (current, 0);
    final sorted = readingDays.toList()..sort();
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
}
