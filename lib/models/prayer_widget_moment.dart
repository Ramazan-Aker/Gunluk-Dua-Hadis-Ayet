class PrayerWidgetMoment {
  const PrayerWidgetMoment({
    required this.name,
    required this.time,
    required this.at,
  });

  final String name;
  final String time;
  final DateTime at;

  Map<String, dynamic> toJson() => {
        'name': name,
        'time': time,
        'at': at.millisecondsSinceEpoch,
      };

  factory PrayerWidgetMoment.fromJson(Map<String, dynamic> json) {
    return PrayerWidgetMoment(
      name: json['name'] as String? ?? '',
      time: json['time'] as String? ?? '',
      at: DateTime.fromMillisecondsSinceEpoch(json['at'] as int? ?? 0),
    );
  }
}
