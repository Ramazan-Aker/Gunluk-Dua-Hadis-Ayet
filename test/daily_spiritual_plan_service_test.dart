import 'package:daily_dua_hadith/models/prayer_tracking.dart';
import 'package:daily_dua_hadith/services/daily_spiritual_plan_service.dart';
import 'package:daily_dua_hadith/services/dhikr_tracking_service.dart';
import 'package:daily_dua_hadith/services/prayer_tracking_service.dart';
import 'package:daily_dua_hadith/services/quran_progress_service.dart';
import 'package:daily_dua_hadith/services/quran_reading_plan_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('varsayılan plan üç temel hedefle başlar', () async {
    final summary = await DailySpiritualPlanService().loadSummary(
      now: DateTime(2026, 8, 10),
    );

    expect(summary.tasks.map((task) => task.id), [
      DailySpiritualPlanService.dailyContentId,
      DailySpiritualPlanService.prayerId,
      DailySpiritualPlanService.dhikrId,
    ]);
    expect(summary.completedCount, 0);
    expect(summary.progress, 0);
  });

  test('ilgili modüllerdeki tamamlamalar günlük plana yansır', () async {
    final now = DateTime(2026, 8, 10);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_read_date', '2026-08-10');

    final prayer = PrayerTrackingService();
    await prayer.setDefaultGoal(1, now: now);
    await prayer.togglePrayer(TrackedPrayer.sabah, now: now);

    final dhikr = DhikrTrackingService();
    await dhikr.setTarget(1, now: now);
    await dhikr.increment(now: now);

    final quranPlan = QuranReadingPlanService();
    await quranPlan.createPlan(
      targetDate: DateTime(2026, 9, 8),
      now: now,
    );
    await QuranProgressService().setJuzCompleted(1, true, now: now);

    final summary = await DailySpiritualPlanService().loadSummary(now: now);

    expect(summary.tasks.length, 4);
    expect(summary.tasks.every((task) => task.completed), isTrue);
    expect(summary.completed, isTrue);
    expect(summary.currentStreak, 1);
  });

  test('kişisel hedef tamamlanır ve günlük seri oluşturur', () async {
    final service = DailySpiritualPlanService();
    final firstDay = DateTime(2026, 8, 10);
    for (final id in DailySpiritualPlanService.coreTaskIds) {
      await service.setCoreTaskEnabled(id, false, now: firstDay);
    }
    var summary = await service.addCustomTask('Sadaka ver', now: firstDay);
    final customId = summary.tasks.single.id;

    summary = await service.toggleCustomTask(customId, now: firstDay);
    expect(summary.completed, isTrue);
    expect(summary.currentStreak, 1);

    summary = await service.toggleCustomTask(
      customId,
      now: firstDay.add(const Duration(days: 1)),
    );
    expect(summary.completed, isTrue);
    expect(summary.currentStreak, 2);
    expect(summary.longestStreak, 2);
  });

  test('temel hedefler kullanıcı tarafından açılıp kapatılabilir', () async {
    final service = DailySpiritualPlanService();
    final date = DateTime(2026, 8, 10);

    var summary = await service.setCoreTaskEnabled(
      DailySpiritualPlanService.prayerId,
      false,
      now: date,
    );
    expect(
      summary.tasks
          .any((task) => task.id == DailySpiritualPlanService.prayerId),
      isFalse,
    );

    summary = await service.setCoreTaskEnabled(
      DailySpiritualPlanService.prayerId,
      true,
      now: date,
    );
    expect(
      summary.tasks
          .any((task) => task.id == DailySpiritualPlanService.prayerId),
      isTrue,
    );
  });

  test('en fazla sekiz kişisel hedef eklenebilir', () async {
    final service = DailySpiritualPlanService();
    final date = DateTime(2026, 8, 10);
    for (var index = 0; index < 8; index++) {
      await service.addCustomTask('Hedef $index', now: date);
    }

    expect(
      () => service.addCustomTask('Dokuzuncu hedef', now: date),
      throwsStateError,
    );
  });
}
