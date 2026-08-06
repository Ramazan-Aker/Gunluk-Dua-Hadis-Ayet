import 'package:shared_preferences/shared_preferences.dart';

import '../models/prayer_times.dart';
import '../models/turkish_city.dart';
import 'notification_service.dart';

class PrayerNotificationService {
  static const _enabledKey = 'prayer_notifications_enabled';
  static const _leadKey = 'prayer_notifications_lead_minutes';
  static const _cityKey = 'prayer_notifications_city_id';
  static const _firstId = 10000;
  static const _lastId = 10059;

  final NotificationService _notifications = NotificationService();

  Future<bool> isEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_enabledKey) ?? false;

  Future<int> leadMinutes() async =>
      (await SharedPreferences.getInstance()).getInt(_leadKey) ?? 10;

  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
    await cancelPrayerNotifications();
  }

  Future<int> enableAndSchedule({
    required TurkishCity city,
    required List<PrayerTimes> prayerTimes,
    required int leadMinutes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);
    await prefs.setInt(_leadKey, leadMinutes);
    await prefs.setString(_cityKey, city.id);
    return schedule(
        city: city, prayerTimes: prayerTimes, leadMinutes: leadMinutes);
  }

  Future<int> schedule({
    required TurkishCity city,
    required List<PrayerTimes> prayerTimes,
    required int leadMinutes,
  }) async {
    await cancelPrayerNotifications();
    final now = DateTime.now();
    var scheduled = 0;
    var id = _firstId;

    for (final day in prayerTimes) {
      if (scheduled >= 55) break;
      final prayers = <(String, String)>[
        ('İmsak', day.imsak),
        ('Öğle', day.ogle),
        ('İkindi', day.ikindi),
        ('Akşam', day.aksam),
        ('Yatsı', day.yatsi),
      ];
      for (final prayer in prayers) {
        if (scheduled >= 55) break;
        final parts = prayer.$2.split(':');
        if (parts.length < 2) continue;
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour == null || minute == null) continue;
        final prayerAt =
            DateTime(day.date.year, day.date.month, day.date.day, hour, minute);
        final notifyAt = prayerAt.subtract(Duration(minutes: leadMinutes));
        if (!notifyAt.isAfter(now)) continue;
        final beforeText = leadMinutes == 0
            ? 'vakti geldi'
            : 'vaktine $leadMinutes dakika kaldı';
        final success = await _notifications.schedulePrayerNotification(
          id: id++,
          title: '${prayer.$1} $beforeText',
          body: '${city.name} • ${prayer.$2}',
          scheduledAt: notifyAt,
        );
        if (success) scheduled++;
      }
    }
    return scheduled;
  }

  Future<void> cancelPrayerNotifications() async {
    for (var id = _firstId; id <= _lastId; id++) {
      await _notifications.cancelNotification(id);
    }
  }
}
