import 'package:daily_dua_hadith/models/kaza_prayer_tracking.dart';
import 'package:daily_dua_hadith/models/prayer_tracking.dart';
import 'package:daily_dua_hadith/models/spiritual_statistics.dart';
import 'package:daily_dua_hadith/services/dhikr_tracking_service.dart';
import 'package:daily_dua_hadith/services/kaza_prayer_service.dart';
import 'package:daily_dua_hadith/services/prayer_tracking_service.dart';
import 'package:daily_dua_hadith/services/quran_progress_service.dart';
import 'package:daily_dua_hadith/services/spiritual_statistics_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('haftalık veriler tüm takip alanlarından birleştirilir', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final prayer = PrayerTrackingService();
    await prayer.togglePrayer(TrackedPrayer.sabah, now: today);
    await prayer.togglePrayer(TrackedPrayer.ogle, now: today);

    final dhikr = DhikrTrackingService();
    await dhikr.increment(now: today);
    await dhikr.increment(now: today);

    final quran = QuranProgressService();
    await quran.setJuzCompleted(1, true, now: today);
    await quran.setJuzCompleted(
      2,
      true,
      now: today.subtract(const Duration(days: 1)),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'daily_spiritual_plan_achievements_v1',
      [today.toIso8601String()],
    );

    final kaza = KazaPrayerService();
    await kaza.addDebt(KazaPrayerType.fajr, 2);
    await kaza.markPerformed(KazaPrayerType.fajr);

    final summary = await SpiritualStatisticsService(
      prayerService: prayer,
      dhikrService: dhikr,
      quranService: quran,
      kazaService: kaza,
    ).load(period: StatisticsPeriod.week, now: today);

    expect(summary.days, hasLength(7));
    expect(summary.totalPrayers, 2);
    expect(summary.totalDhikr, 2);
    expect(summary.totalCompletedJuz, 2);
    expect(summary.completedPlanDays, 1);
    expect(summary.totalKazaPerformed, 1);
    expect(summary.activeDays, 2);
  });

  test('aylık görünüm tam 30 gün üretir', () async {
    final summary = await SpiritualStatisticsService().load(
      period: StatisticsPeriod.month,
      now: DateTime(2026, 8, 10),
    );

    expect(summary.days, hasLength(30));
    expect(summary.days.first.date, DateTime(2026, 7, 12));
    expect(summary.days.last.date, DateTime(2026, 8, 10));
  });
}
