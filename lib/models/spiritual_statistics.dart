enum StatisticsPeriod {
  week(7, '7 Gün'),
  month(30, '30 Gün');

  const StatisticsPeriod(this.dayCount, this.label);
  final int dayCount;
  final String label;
}

class SpiritualStatisticsDay {
  final DateTime date;
  final int prayers;
  final int dhikr;
  final int completedJuz;
  final bool dailyPlanCompleted;
  final int kazaPerformed;

  const SpiritualStatisticsDay({
    required this.date,
    this.prayers = 0,
    this.dhikr = 0,
    this.completedJuz = 0,
    this.dailyPlanCompleted = false,
    this.kazaPerformed = 0,
  });
}

class SpiritualStatisticsSummary {
  final StatisticsPeriod period;
  final List<SpiritualStatisticsDay> days;

  const SpiritualStatisticsSummary({required this.period, required this.days});

  int get totalPrayers => days.fold(0, (total, day) => total + day.prayers);
  int get totalDhikr => days.fold(0, (total, day) => total + day.dhikr);
  int get totalCompletedJuz =>
      days.fold(0, (total, day) => total + day.completedJuz);
  int get completedPlanDays =>
      days.where((day) => day.dailyPlanCompleted).length;
  int get totalKazaPerformed =>
      days.fold(0, (total, day) => total + day.kazaPerformed);
  int get activeDays => days
      .where((day) =>
          day.prayers > 0 ||
          day.dhikr > 0 ||
          day.completedJuz > 0 ||
          day.dailyPlanCompleted ||
          day.kazaPerformed > 0)
      .length;
  double get prayerCompletionRatio =>
      days.isEmpty ? 0 : totalPrayers / (days.length * 5);
}
