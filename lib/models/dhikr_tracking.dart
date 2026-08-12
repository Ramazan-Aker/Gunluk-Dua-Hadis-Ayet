class DhikrOption {
  const DhikrOption({
    required this.id,
    required this.title,
    required this.arabic,
    required this.meaning,
    required this.defaultTarget,
  });

  final String id;
  final String title;
  final String arabic;
  final String meaning;
  final int defaultTarget;

  static const presets = <DhikrOption>[
    DhikrOption(
      id: 'subhanallah',
      title: 'Sübhanallah',
      arabic: 'سُبْحَانَ اللّٰهِ',
      meaning: 'Allah’ı tüm eksikliklerden tenzih ederim.',
      defaultTarget: 33,
    ),
    DhikrOption(
      id: 'elhamdulillah',
      title: 'Elhamdülillah',
      arabic: 'اَلْحَمْدُ لِلّٰهِ',
      meaning: 'Hamd Allah’a mahsustur.',
      defaultTarget: 33,
    ),
    DhikrOption(
      id: 'allahu_ekber',
      title: 'Allahu Ekber',
      arabic: 'اَللّٰهُ أَكْبَرُ',
      meaning: 'Allah en büyüktür.',
      defaultTarget: 33,
    ),
    DhikrOption(
      id: 'la_ilahe_illallah',
      title: 'Lâ ilâhe illallah',
      arabic: 'لَا إِلٰهَ إِلَّا اللّٰهُ',
      meaning: 'Allah’tan başka ilah yoktur.',
      defaultTarget: 100,
    ),
    DhikrOption(
      id: 'salavat',
      title: 'Salavat',
      arabic: 'اَللّٰهُمَّ صَلِّ عَلٰى مُحَمَّدٍ',
      meaning: 'Allah’ım, Muhammed’e salât eyle.',
      defaultTarget: 100,
    ),
  ];

  static DhikrOption fromId(String? id) {
    for (final option in presets) {
      if (option.id == id) return option;
    }
    return presets.first;
  }
}

class DhikrDayProgress {
  const DhikrDayProgress({
    required this.date,
    required this.counts,
    this.goalMet = false,
  });

  final DateTime date;
  final Map<String, int> counts;
  final bool goalMet;

  int countFor(String optionId) => counts[optionId] ?? 0;
  int get totalCount => counts.values.fold(0, (total, count) => total + count);

  DhikrDayProgress copyWith({
    Map<String, int>? counts,
    bool? goalMet,
  }) {
    return DhikrDayProgress(
      date: date,
      counts: counts ?? this.counts,
      goalMet: goalMet ?? this.goalMet,
    );
  }

  Map<String, dynamic> toJson() => {
        'counts': counts,
        'goalMet': goalMet,
      };

  factory DhikrDayProgress.fromJson(
    DateTime date,
    Map<String, dynamic> json,
  ) {
    final rawCounts = json['counts'];
    final counts = <String, int>{};
    if (rawCounts is Map<String, dynamic>) {
      for (final entry in rawCounts.entries) {
        final value = entry.value;
        if (value is int && value >= 0) counts[entry.key] = value;
      }
    }
    return DhikrDayProgress(
      date: date,
      counts: counts,
      goalMet: json['goalMet'] == true,
    );
  }
}

class DhikrTrackingSummary {
  const DhikrTrackingSummary({
    required this.option,
    required this.today,
    required this.target,
    required this.week,
    required this.currentStreak,
    required this.longestStreak,
  });

  final DhikrOption option;
  final DhikrDayProgress today;
  final int target;
  final List<DhikrDayProgress> week;
  final int currentStreak;
  final int longestStreak;

  int get count => today.countFor(option.id);
  int get remaining => (target - count).clamp(0, target);
  double get progress => (count / target).clamp(0, 1);
}
