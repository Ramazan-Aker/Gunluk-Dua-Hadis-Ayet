enum DailyPlanTaskType { dailyContent, prayer, dhikr, quran, custom }

class DailyPlanCustomTask {
  const DailyPlanCustomTask({
    required this.id,
    required this.title,
    required this.createdAt,
  });

  final String id;
  final String title;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DailyPlanCustomTask.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final title = json['title'] as String?;
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    if (id == null ||
        id.isEmpty ||
        title == null ||
        title.isEmpty ||
        createdAt == null) {
      throw const FormatException('Geçersiz kişisel hedef');
    }
    return DailyPlanCustomTask(id: id, title: title, createdAt: createdAt);
  }
}

class DailyPlanTaskStatus {
  const DailyPlanTaskStatus({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.completed,
    this.customTask,
  });

  final String id;
  final DailyPlanTaskType type;
  final String title;
  final String subtitle;
  final double progress;
  final bool completed;
  final DailyPlanCustomTask? customTask;
}

class DailySpiritualPlanSummary {
  const DailySpiritualPlanSummary({
    required this.date,
    required this.tasks,
    required this.currentStreak,
    required this.longestStreak,
    required this.week,
    required this.enabledCoreTaskIds,
  });

  final DateTime date;
  final List<DailyPlanTaskStatus> tasks;
  final int currentStreak;
  final int longestStreak;
  final List<DailyPlanWeekDay> week;
  final Set<String> enabledCoreTaskIds;

  int get completedCount => tasks.where((task) => task.completed).length;
  bool get completed => tasks.isNotEmpty && completedCount == tasks.length;
  double get progress => tasks.isEmpty
      ? 0
      : tasks.fold<double>(0, (total, task) => total + task.progress) /
          tasks.length;
}

class DailyPlanWeekDay {
  const DailyPlanWeekDay({required this.date, required this.completed});

  final DateTime date;
  final bool completed;
}
