import 'dart:math' as math;

class QuranReadingPlan {
  const QuranReadingPlan({
    required this.startedAt,
    required this.targetDate,
    required this.startingCompletedCount,
  });

  final DateTime startedAt;
  final DateTime targetDate;
  final int startingCompletedCount;

  Map<String, dynamic> toJson() => {
        'startedAt': _dateKey(startedAt),
        'targetDate': _dateKey(targetDate),
        'startingCompletedCount': startingCompletedCount,
      };

  factory QuranReadingPlan.fromJson(Map<String, dynamic> json) {
    final startedAt = DateTime.tryParse(json['startedAt'] as String? ?? '');
    final targetDate = DateTime.tryParse(json['targetDate'] as String? ?? '');
    final startingCompletedCount = json['startingCompletedCount'] as int?;
    if (startedAt == null ||
        targetDate == null ||
        startingCompletedCount == null ||
        startingCompletedCount < 0 ||
        startingCompletedCount > 30) {
      throw const FormatException('Geçersiz hatim planı');
    }
    return QuranReadingPlan(
      startedAt: _dateOnly(startedAt),
      targetDate: _dateOnly(targetDate),
      startingCompletedCount: startingCompletedCount,
    );
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

class QuranReadingPlanSummary {
  const QuranReadingPlanSummary({
    required this.plan,
    required this.completedJuz,
    required this.completionDates,
    required this.today,
    required this.currentStreak,
    required this.longestStreak,
  });

  final QuranReadingPlan plan;
  final Set<int> completedJuz;
  final Map<int, DateTime> completionDates;
  final DateTime today;
  final int currentStreak;
  final int longestStreak;

  int get totalToRead => math.max(0, 30 - plan.startingCompletedCount);
  int get completedSinceStart => math.min(totalToRead,
      math.max(0, completedJuz.length - plan.startingCompletedCount));
  int get remainingJuz => math.max(0, 30 - completedJuz.length);
  bool get isComplete => completedJuz.length >= 30;

  int get totalDays =>
      math.max(1, plan.targetDate.difference(plan.startedAt).inDays + 1);
  int get remainingDays =>
      math.max(0, plan.targetDate.difference(today).inDays + 1);
  bool get isOverdue => !isComplete && today.isAfter(plan.targetDate);
  int get overdueDays =>
      isOverdue ? today.difference(plan.targetDate).inDays : 0;

  double get plannedDailyJuz =>
      totalToRead == 0 ? 0 : totalToRead / totalDays;

  /// Plan başladıktan sonra bugün tamamlanan cüz sayısı.
  /// Plan oluşturulmadan önce aynı gün okunmuş cüzler yeni hedefe sayılmaz.
  int get completedTodayForPlan => math.min(completedSinceStart, completedToday);

  int get todayTarget {
    if (isComplete) return 0;
    if (remainingDays <= 0) return remainingJuz + completedTodayForPlan;

    final elapsedDays = math.min(
      totalDays,
      math.max(1, today.difference(plan.startedAt).inDays + 1),
    );
    final expectedByToday = (totalToRead * elapsedDays / totalDays).ceil();
    final completedBeforeToday =
        math.max(0, completedSinceStart - completedTodayForPlan);
    final dueBySchedule = math.max(0, expectedByToday - completedBeforeToday);
    if (dueBySchedule == 0) return 0;

    // Geride kalındığında bütün açığı tek güne yığmak yerine kalan günlere
    // dengeli dağıt. Bugün okunanlar eklendiği için hedef gün içinde sabit kalır.
    final remainingAtStartOfToday = remainingJuz + completedTodayForPlan;
    final adaptiveTarget = (remainingAtStartOfToday / remainingDays).ceil();
    return math.min(dueBySchedule, adaptiveTarget);
  }

  int get completedToday =>
      completionDates.values.where((date) => _sameDay(date, today)).length;

  double get progress => (completedJuz.length / 30).clamp(0, 1);

  List<int> get recommendedJuz {
    final remainingToday = math.max(0, todayTarget - completedTodayForPlan);
    if (remainingToday == 0) return const [];
    return [
      for (var number = 1; number <= 30; number++)
        if (!completedJuz.contains(number)) number,
    ].take(remainingToday).toList();
  }

  bool get isOnTrack {
    if (isComplete) return true;
    final elapsed = math.min(
      totalDays,
      math.max(1, today.difference(plan.startedAt).inDays + 1),
    );
    final expected = (totalToRead * elapsed / totalDays).floor();
    return completedSinceStart >= expected;
  }

  List<QuranReadingDay> get week {
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    return List.generate(7, (index) {
      final date = weekStart.add(Duration(days: index));
      final count =
          completionDates.values.where((value) => _sameDay(value, date)).length;
      return QuranReadingDay(date: date, completedJuz: count);
    });
  }

  static bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

class QuranReadingDay {
  const QuranReadingDay({required this.date, required this.completedJuz});

  final DateTime date;
  final int completedJuz;

  bool get hasReading => completedJuz > 0;
}
