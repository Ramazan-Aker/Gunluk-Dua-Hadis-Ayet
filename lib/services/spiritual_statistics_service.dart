import '../models/spiritual_statistics.dart';
import 'daily_spiritual_plan_service.dart';
import 'dhikr_tracking_service.dart';
import 'kaza_prayer_service.dart';
import 'prayer_tracking_service.dart';
import 'quran_progress_service.dart';

class SpiritualStatisticsService {
  final PrayerTrackingService _prayerService;
  final DhikrTrackingService _dhikrService;
  final QuranProgressService _quranService;
  final DailySpiritualPlanService _planService;
  final KazaPrayerService _kazaService;

  SpiritualStatisticsService({
    PrayerTrackingService? prayerService,
    DhikrTrackingService? dhikrService,
    QuranProgressService? quranService,
    DailySpiritualPlanService? planService,
    KazaPrayerService? kazaService,
  })  : _prayerService = prayerService ?? PrayerTrackingService(),
        _dhikrService = dhikrService ?? DhikrTrackingService(),
        _quranService = quranService ?? QuranProgressService(),
        _planService = planService ?? DailySpiritualPlanService(),
        _kazaService = kazaService ?? KazaPrayerService();

  Future<SpiritualStatisticsSummary> load({
    StatisticsPeriod period = StatisticsPeriod.week,
    DateTime? now,
  }) async {
    final today = _dateOnly(now ?? DateTime.now());
    final start = today.subtract(Duration(days: period.dayCount - 1));

    final prayerHistory = await _prayerService.loadHistory();
    final dhikrHistory = await _dhikrService.loadHistory(forceReload: true);
    final quranDates = await _quranService.completionDates();
    final planDates = await _planService.achievementDates();
    final kazaHistory = await _kazaService.loadHistory();

    final prayersByDate = {
      for (final day in prayerHistory) _dateOnly(day.date): day.completedCount,
    };
    final dhikrByDate = {
      for (final day in dhikrHistory) _dateOnly(day.date): day.totalCount,
    };
    final juzByDate = <DateTime, int>{};
    for (final date in quranDates.values) {
      final day = _dateOnly(date);
      juzByDate[day] = (juzByDate[day] ?? 0) + 1;
    }
    final completedPlans = planDates.map(_dateOnly).toSet();
    final kazaByDate = <DateTime, int>{};
    for (final item in kazaHistory.where((item) => item.isPerformed)) {
      final day = _dateOnly(item.createdAt);
      kazaByDate[day] = (kazaByDate[day] ?? 0) + item.amount;
    }

    final days = List.generate(period.dayCount, (index) {
      final date = start.add(Duration(days: index));
      return SpiritualStatisticsDay(
        date: date,
        prayers: prayersByDate[date] ?? 0,
        dhikr: dhikrByDate[date] ?? 0,
        completedJuz: juzByDate[date] ?? 0,
        dailyPlanCompleted: completedPlans.contains(date),
        kazaPerformed: kazaByDate[date] ?? 0,
      );
    });
    return SpiritualStatisticsSummary(period: period, days: days);
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
