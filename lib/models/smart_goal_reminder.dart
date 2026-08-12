enum SmartGoalType { prayer, dhikr, quran, dailyPlan }

class SmartGoalReminderSetting {
  const SmartGoalReminderSetting({
    required this.type,
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  final SmartGoalType type;
  final bool enabled;
  final int hour;
  final int minute;

  SmartGoalReminderSetting copyWith({
    bool? enabled,
    int? hour,
    int? minute,
  }) {
    return SmartGoalReminderSetting(
      type: type,
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'enabled': enabled,
        'hour': hour,
        'minute': minute,
      };

  factory SmartGoalReminderSetting.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String?;
    final type = SmartGoalType.values
        .where((value) => value.name == typeName)
        .firstOrNull;
    final hour = json['hour'] as int?;
    final minute = json['minute'] as int?;
    if (type == null ||
        hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      throw const FormatException('Geçersiz akıllı hatırlatma');
    }
    return SmartGoalReminderSetting(
      type: type,
      enabled: json['enabled'] == true,
      hour: hour,
      minute: minute,
    );
  }
}

extension SmartGoalTypeUi on SmartGoalType {
  String get title => switch (this) {
        SmartGoalType.prayer => 'Namaz hedefi',
        SmartGoalType.dhikr => 'Zikir hedefi',
        SmartGoalType.quran => 'Hatim hedefi',
        SmartGoalType.dailyPlan => 'Günlük Manevi Plan',
      };

  String get description => switch (this) {
        SmartGoalType.prayer => 'Günlük namaz hedefin eksikse hatırlatır.',
        SmartGoalType.dhikr => 'Seçtiğin zikir hedefine ulaşmanı hatırlatır.',
        SmartGoalType.quran =>
          'Hatim planındaki günlük cüz hedefini hatırlatır.',
        SmartGoalType.dailyPlan =>
          'Günlük planında kalan maddeleri hatırlatır.',
      };
}
