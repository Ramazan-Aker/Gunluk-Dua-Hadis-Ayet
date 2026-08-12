enum AchievementId {
  firstDailyRead,
  dailyReadWeek,
  firstPrayerGoal,
  prayerWeek,
  firstDhikrGoal,
  dhikrThousand,
  firstJuz,
  firstHatim,
  firstDailyPlan,
  dailyPlanWeek,
}

class AchievementDefinition {
  const AchievementDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.target,
    required this.symbol,
  });

  final AchievementId id;
  final String title;
  final String description;
  final int target;
  final String symbol;
}

class AchievementStatus {
  const AchievementStatus({
    required this.definition,
    required this.current,
    this.unlockedAt,
  });

  final AchievementDefinition definition;
  final int current;
  final DateTime? unlockedAt;

  bool get unlocked => unlockedAt != null;
  double get progress => (current / definition.target).clamp(0, 1).toDouble();
}

class AchievementSummary {
  const AchievementSummary({
    required this.achievements,
    required this.newlyUnlocked,
  });

  final List<AchievementStatus> achievements;
  final List<AchievementStatus> newlyUnlocked;

  int get unlockedCount =>
      achievements.where((achievement) => achievement.unlocked).length;
}
