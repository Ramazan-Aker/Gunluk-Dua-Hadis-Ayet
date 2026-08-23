import 'package:daily_dua_hadith/services/quran_progress_service.dart';
import 'package:daily_dua_hadith/services/quran_reading_plan_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('plan mevcut okunan cüzlerden devam eder', () async {
    SharedPreferences.setMockInitialValues({
      'quran_completed_juz_v1': [
        for (var number = 1; number <= 8; number++) '$number',
      ],
    });
    final service = QuranReadingPlanService();
    final now = DateTime(2026, 8, 10);

    final summary = await service.createPlan(
      targetDate: DateTime(2026, 9, 8),
      now: now,
    );

    expect(summary.plan.startingCompletedCount, 8);
    expect(summary.totalToRead, 22);
    expect(summary.remainingJuz, 22);
    expect(summary.plannedDailyJuz, closeTo(22 / 30, 0.0001));
    expect(summary.progress, closeTo(8 / 30, 0.0001));
    expect(summary.recommendedJuz.first, 9);
  });

  test('gecikince günlük hedef kalan süreye göre yükselir', () async {
    final service = QuranReadingPlanService();
    await service.createPlan(
      targetDate: DateTime(2026, 8, 10),
      now: DateTime(2026, 8, 1),
    );

    final summary = await service.loadSummary(now: DateTime(2026, 8, 6));

    expect(summary, isNotNull);
    expect(summary!.remainingDays, 5);
    expect(summary.todayTarget, 6);
    expect(summary.recommendedJuz, [1, 2, 3, 4, 5, 6]);
  });

  test('60 günlük plan cüz hedefini günlere dengeli dağıtır', () async {
    final progress = QuranProgressService();
    final service = QuranReadingPlanService(progressService: progress);
    final start = DateTime(2026, 8, 1);
    await service.createPlan(
      targetDate: DateTime(2026, 9, 29),
      now: start,
    );

    var summary = await service.loadSummary(now: start);
    expect(summary!.plannedDailyJuz, 0.5);
    expect(summary.todayTarget, 1);

    await progress.setJuzCompleted(1, true, now: start);
    summary = await service.loadSummary(now: start.add(const Duration(days: 1)));
    expect(summary!.todayTarget, 0);
    expect(summary.recommendedJuz, isEmpty);

    summary = await service.loadSummary(now: start.add(const Duration(days: 2)));
    expect(summary!.todayTarget, 1);
    expect(summary.recommendedJuz, [2]);
  });

  test('cüz tamamlama tarihleri okuma serisini oluşturur', () async {
    final progress = QuranProgressService();
    final service = QuranReadingPlanService(progressService: progress);
    await service.createPlan(
      targetDate: DateTime(2026, 9, 1),
      now: DateTime(2026, 8, 1),
    );
    await progress.setJuzCompleted(1, true, now: DateTime(2026, 8, 1));
    await progress.setJuzCompleted(2, true, now: DateTime(2026, 8, 2));

    final summary = await service.loadSummary(now: DateTime(2026, 8, 3));

    expect(summary!.currentStreak, 2);
    expect(summary.longestStreak, 2);
    expect(summary.completedToday, 0);
  });

  test('cüz tarihi ilk işaretlendiği günü korur ve kaldırılabilir', () async {
    final progress = QuranProgressService();
    await progress.setJuzCompleted(4, true, now: DateTime(2026, 8, 4));
    await progress.setJuzCompleted(4, true, now: DateTime(2026, 8, 8));

    var dates = await progress.completionDates();
    expect(dates[4], DateTime(2026, 8, 4));

    await progress.setJuzCompleted(4, false, now: DateTime(2026, 8, 9));
    dates = await progress.completionDates();
    expect(dates.containsKey(4), isFalse);
  });

  test('geçmiş tarihli plan oluşturulamaz', () async {
    final service = QuranReadingPlanService();

    expect(
      () => service.createPlan(
        targetDate: DateTime(2026, 8, 9),
        now: DateTime(2026, 8, 10),
      ),
      throwsArgumentError,
    );
  });
}
