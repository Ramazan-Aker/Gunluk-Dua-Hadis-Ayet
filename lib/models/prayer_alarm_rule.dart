import 'prayer_times.dart';
import 'turkish_city.dart';
import 'package:timezone/timezone.dart' as tz;

enum AlarmPrayer {
  fajr('Sabah (İmsak)'),
  sunrise('Güneş'),
  dhuhr('Öğle'),
  asr('İkindi'),
  maghrib('Akşam'),
  isha('Yatsı');

  const AlarmPrayer(this.label);
  final String label;
  String timeOf(PrayerTimes day) => switch (this) {
        fajr => day.imsak,
        sunrise => day.gunes,
        dhuhr => day.ogle,
        asr => day.ikindi,
        maghrib => day.aksam,
        isha => day.yatsi,
      };
}

class PrayerAlarmRule {
  const PrayerAlarmRule(
      {required this.id,
      required this.city,
      required this.weekdays,
      required this.prayers,
      this.leadMinutes = 10,
      this.enabled = true});
  final String id;
  final TurkishCity city;
  final Set<int> weekdays;
  final Set<AlarmPrayer> prayers;
  final int leadMinutes;
  final bool enabled;
  PrayerAlarmRule withEnabled(bool value) => PrayerAlarmRule(
      id: id,
      city: city,
      weekdays: weekdays,
      prayers: prayers,
      leadMinutes: leadMinutes,
      enabled: value);
  Map<String, dynamic> toJson() => {
        'id': id,
        'city': city.toJson(),
        'weekdays': weekdays.toList()..sort(),
        'prayers': prayers.map((p) => p.name).toList(),
        'leadMinutes': leadMinutes,
        'enabled': enabled
      };
  factory PrayerAlarmRule.fromJson(Map<String, dynamic> json) {
    final days = (json['weekdays'] as List).cast<int>().toSet();
    final prayers = (json['prayers'] as List)
        .map((p) => AlarmPrayer.values.byName(p as String))
        .toSet();
    final lead = json['leadMinutes'] as int;
    if (days.isEmpty ||
        days.any((d) => d < 1 || d > 7) ||
        prayers.isEmpty ||
        lead < 0 ||
        lead > 120) {
      throw const FormatException('Geçersiz alarm kuralı');
    }
    return PrayerAlarmRule(
        id: json['id'] as String,
        city: TurkishCity.fromJson(
            Map<String, dynamic>.from(json['city'] as Map)),
        weekdays: days,
        prayers: prayers,
        leadMinutes: lead,
        enabled: json['enabled'] == true);
  }
}

class PlannedPrayerAlarm {
  const PlannedPrayerAlarm(
      {required this.city,
      required this.prayer,
      required this.prayerAt,
      required this.notifyAt,
      required this.leadMinutes});
  final TurkishCity city;
  final AlarmPrayer prayer;
  final DateTime prayerAt;
  final DateTime notifyAt;
  final int leadMinutes;
}

/// Days refer to the prayer day, even for reminders the night before.
List<PlannedPrayerAlarm> planPrayerAlarms(
    List<PrayerAlarmRule> rules, Map<String, List<PrayerTimes>> times,
    {required DateTime now, int limit = 55}) {
  final location = tz.getLocation('Europe/Istanbul');
  final alarms = <String, PlannedPrayerAlarm>{};
  for (final rule in rules.where((r) => r.enabled)) {
    for (final day in times[rule.city.id] ?? <PrayerTimes>[]) {
      if (!rule.weekdays.contains(day.date.weekday)) continue;
      for (final prayer in rule.prayers) {
        final clock = prayer.timeOf(day);
        if (!RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(clock)) continue;
        final parts = clock.split(':').map(int.parse).toList();
        final at = tz.TZDateTime(location, day.date.year, day.date.month,
            day.date.day, parts[0], parts[1]);
        final notify = at.subtract(Duration(minutes: rule.leadMinutes));
        if (!notify.isAfter(now)) continue;
        final key =
            '${rule.city.id}/${prayer.name}/${notify.millisecondsSinceEpoch}';
        alarms[key] = PlannedPrayerAlarm(
            city: rule.city,
            prayer: prayer,
            prayerAt: at,
            notifyAt: notify,
            leadMinutes: rule.leadMinutes);
      }
    }
  }
  final result = alarms.values.toList()
    ..sort((a, b) {
      final time = a.notifyAt.compareTo(b.notifyAt);
      return time != 0
          ? time
          : '${a.city.id}/${a.prayer.name}'
              .compareTo('${b.city.id}/${b.prayer.name}');
    });
  return result.take(limit.clamp(0, 55)).toList();
}
