enum TrackedPrayer {
  sabah('sabah', 'Sabah'),
  ogle('ogle', 'Öğle'),
  ikindi('ikindi', 'İkindi'),
  aksam('aksam', 'Akşam'),
  yatsi('yatsi', 'Yatsı');

  const TrackedPrayer(this.id, this.label);

  final String id;
  final String label;

  static TrackedPrayer? fromId(String id) {
    for (final prayer in values) {
      if (prayer.id == id) return prayer;
    }
    return null;
  }
}

class PrayerTrackingDay {
  const PrayerTrackingDay({
    required this.date,
    required this.completed,
    required this.goal,
    this.isPaused = false,
  });

  final DateTime date;
  final Set<TrackedPrayer> completed;
  final int goal;
  final bool isPaused;

  int get completedCount => completed.length;
  bool get goalMet => !isPaused && completedCount >= goal;
  double get progress => isPaused ? 0 : (completedCount / goal).clamp(0, 1);

  PrayerTrackingDay copyWith({
    Set<TrackedPrayer>? completed,
    int? goal,
    bool? isPaused,
  }) {
    return PrayerTrackingDay(
      date: date,
      completed: completed ?? this.completed,
      goal: goal ?? this.goal,
      isPaused: isPaused ?? this.isPaused,
    );
  }

  Map<String, dynamic> toJson() => {
        'completed': completed.map((prayer) => prayer.id).toList(),
        'goal': goal,
        'paused': isPaused,
      };

  factory PrayerTrackingDay.fromJson(
    DateTime date,
    Map<String, dynamic> json,
    int fallbackGoal,
  ) {
    final completed = (json['completed'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .map(TrackedPrayer.fromId)
        .whereType<TrackedPrayer>()
        .toSet();
    final storedGoal = json['goal'] as int?;
    final goal = PrayerTrackingSummary.allowedGoals.contains(storedGoal)
        ? storedGoal!
        : fallbackGoal;
    return PrayerTrackingDay(
      date: date,
      completed: completed,
      goal: goal,
      isPaused: json['paused'] == true,
    );
  }
}

class PrayerTrackingSummary {
  const PrayerTrackingSummary({
    required this.today,
    required this.week,
    required this.currentStreak,
    required this.longestStreak,
    required this.defaultGoal,
  });

  static const allowedGoals = <int>{1, 3, 5};

  final PrayerTrackingDay today;
  final List<PrayerTrackingDay> week;
  final int currentStreak;
  final int longestStreak;
  final int defaultGoal;

  int get completedThisWeek => week.where((day) => day.goalMet).length;
}
