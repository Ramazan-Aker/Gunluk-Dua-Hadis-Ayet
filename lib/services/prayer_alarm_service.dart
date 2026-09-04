import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/prayer_alarm_rule.dart';
import '../models/prayer_times.dart';
import '../models/turkish_city.dart';
import 'notification_service.dart';
import 'ramadan_api_service.dart';

class PrayerAlarmService {
  static const rulesKey = 'prayer_alarm_rules_v2';
  static const horizonKey = 'prayer_alarm_horizon_v2';
  static Future<int>? _running;
  static DateTime? _lastRefresh;
  final _notifications = NotificationService();
  static List<TurkishCity> get cities => RamadanApiService()
      .getAllTurkishCities()
      .map((c) => TurkishCity.fromJson(c))
      .toList();

  Future<List<PrayerAlarmRule>> loadRules() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(rulesKey);
    if (raw != null) {
      try {
        final result = <PrayerAlarmRule>[];
        for (final row in jsonDecode(raw) as List) {
          try {
            result.add(PrayerAlarmRule.fromJson(
                Map<String, dynamic>.from(row as Map)));
          } catch (_) {/* Preserve other valid rules. */}
        }
        return result;
      } catch (_) {
        return [];
      }
    }
    final cityId = prefs.getString('prayer_notifications_city_id');
    final matching = cities.where((c) => c.id == cityId);
    final result = <PrayerAlarmRule>[];
    if (matching.isNotEmpty) {
      result.add(PrayerAlarmRule(
          id: 'legacy',
          city: matching.first,
          weekdays: {1, 2, 3, 4, 5, 6, 7},
          prayers: {
            AlarmPrayer.fajr,
            AlarmPrayer.dhuhr,
            AlarmPrayer.asr,
            AlarmPrayer.maghrib,
            AlarmPrayer.isha
          },
          leadMinutes: (prefs.getInt('prayer_notifications_lead_minutes') ?? 10)
              .clamp(0, 120),
          enabled: prefs.getBool('prayer_notifications_enabled') ?? false));
    }
    await prefs.setString(
        rulesKey, jsonEncode(result.map((r) => r.toJson()).toList()));
    return result;
  }

  Future<void> saveRules(List<PrayerAlarmRule> rules) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        rulesKey, jsonEncode(rules.map((r) => r.toJson()).toList()));
    await prefs.setBool(
        'prayer_notifications_enabled', rules.any((r) => r.enabled));
    _lastRefresh = null;
  }

  Future<bool> isEnabled() async => (await loadRules()).any((r) => r.enabled);

  Future<int> refresh(
      {bool force = false,
      Map<String, List<PrayerTimes>> knownTimes = const {}}) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return 0;
    if (_running != null) {
      final count = await _running!;
      if (!force) return count;
    }
    if (!force &&
        _lastRefresh != null &&
        DateTime.now().difference(_lastRefresh!) < const Duration(minutes: 15)) {
      return 0;
    }
    final work = _refresh(knownTimes);
    _running = work;
    try {
      return await work;
    } finally {
      if (identical(_running, work)) _running = null;
    }
  }

  Future<int> _refresh(Map<String, List<PrayerTimes>> knownTimes) async {
    try {
      tzdata.initializeTimeZones();
      final rules = await loadRules();
      final prefs = await SharedPreferences.getInstance();
      final now = tz.TZDateTime.now(tz.getLocation('Europe/Istanbul'));
      final start = DateTime(now.year, now.month, now.day);
      final times = <String, List<PrayerTimes>>{};
      for (final id
          in rules.where((r) => r.enabled).map((r) => r.city.id).toSet()) {
        var days = knownTimes[id] ??
            await RamadanApiService().fetchPrayerTimes(
                locationId: id,
                startDate: start,
                endDate: start.add(const Duration(days: 30)));
        final key = 'prayer_alarm_times_$id';
        if (days.isNotEmpty) {
          await prefs.setString(
              key, jsonEncode(days.map((d) => d.toJson()).toList()));
        } else {
          try {
            days = (jsonDecode(prefs.getString(key) ?? '[]') as List)
                .map((row) => PrayerTimes.fromJson(
                    Map<String, dynamic>.from(row as Map),
                    DateTime.parse(row['date'] as String)))
                .toList();
          } catch (_) {
            days = [];
          }
        }
        times[id] = days;
      }
      await _notifications.initialize();
      final pending = await _notifications.getPendingNotifications();
      final otherCount =
          pending.where((p) => p.id < 10000 || p.id > 10059).length;
      final limit = Platform.isIOS ? (60 - otherCount).clamp(0, 55) : 55;
      final plan = planPrayerAlarms(rules, times, now: now, limit: limit);
      for (var id = 10000; id <= 10059; id++) {
        await _notifications.cancelNotification(id);
      }
      var count = 0;
      DateTime? last;
      for (final alarm in plan) {
        final before = alarm.leadMinutes == 0
            ? 'vakti geldi'
            : 'vaktine ${alarm.leadMinutes} dakika kaldı';
        final success = await _notifications.schedulePrayerNotification(
            id: 10000 + count,
            title: '${alarm.prayer.label} $before',
            body:
                '${alarm.city.name} • ${alarm.prayerAt.hour.toString().padLeft(2, '0')}:${alarm.prayerAt.minute.toString().padLeft(2, '0')}',
            scheduledAt: alarm.notifyAt);
        if (success) {
          count++;
          last = alarm.notifyAt;
        }
      }
      if (last == null) {
        await prefs.remove(horizonKey);
      } else {
        await prefs.setString(horizonKey, last.toIso8601String());
      }
      _lastRefresh = DateTime.now();
      return count;
    } catch (error) {
      debugPrint('Prayer alarms refresh failed: $error');
      return 0;
    }
  }
}
