enum KazaPrayerType { fajr, dhuhr, asr, maghrib, isha, witr }

extension KazaPrayerTypeX on KazaPrayerType {
  String get id => name;

  String get label => switch (this) {
        KazaPrayerType.fajr => 'Sabah',
        KazaPrayerType.dhuhr => 'Öğle',
        KazaPrayerType.asr => 'İkindi',
        KazaPrayerType.maghrib => 'Akşam',
        KazaPrayerType.isha => 'Yatsı',
        KazaPrayerType.witr => 'Vitir',
      };

  static KazaPrayerType? fromId(String? id) {
    for (final type in KazaPrayerType.values) {
      if (type.id == id) return type;
    }
    return null;
  }
}

class KazaPrayerTransaction {
  final String id;
  final DateTime createdAt;
  final KazaPrayerType prayer;
  final int change;

  const KazaPrayerTransaction({
    required this.id,
    required this.createdAt,
    required this.prayer,
    required this.change,
  });

  bool get isPerformed => change < 0;
  int get amount => change.abs();

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'prayer': prayer.id,
        'change': change,
      };

  static KazaPrayerTransaction? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    final prayer = KazaPrayerTypeX.fromId(json['prayer'] as String?);
    final change = json['change'];
    if (id is! String ||
        createdAt == null ||
        prayer == null ||
        change is! int ||
        change == 0) {
      return null;
    }
    return KazaPrayerTransaction(
      id: id,
      createdAt: createdAt,
      prayer: prayer,
      change: change,
    );
  }
}

class KazaPrayerSummary {
  final Map<KazaPrayerType, int> debts;
  final List<KazaPrayerTransaction> history;

  const KazaPrayerSummary({required this.debts, required this.history});

  int debtFor(KazaPrayerType prayer) => debts[prayer] ?? 0;
  int get totalDebt => debts.values.fold(0, (total, value) => total + value);
  int get totalPerformed => history
      .where((item) => item.isPerformed)
      .fold(0, (total, item) => total + item.amount);
}
