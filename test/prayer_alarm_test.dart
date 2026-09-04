import 'package:daily_dua_hadith/models/prayer_alarm_rule.dart';
import 'package:daily_dua_hadith/models/prayer_times.dart';
import 'package:daily_dua_hadith/services/prayer_alarm_service.dart';
import 'package:daily_dua_hadith/screens/prayer_alarm_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;

PrayerTimes day(DateTime date,
        {String imsak = '05:00', String ogle = '13:00'}) =>
    PrayerTimes(
        date: date,
        imsak: imsak,
        gunes: '06:30',
        ogle: ogle,
        ikindi: '16:30',
        aksam: '19:00',
        yatsi: '20:30');

void main() {
  setUp(() {
    tz.initializeTimeZones();
    SharedPreferences.setMockInitialValues({});
  });
  final istanbul =
      PrayerAlarmService.cities.firstWhere((c) => c.name == 'İstanbul');
  final ankara =
      PrayerAlarmService.cities.firstWhere((c) => c.name == 'Ankara');
  final friday = DateTime(2026, 9, 4);
  final monday = DateTime(2026, 9, 7);
  test('Different cities, weekdays and prayer selections remain independent',
      () {
    final rules = [
      PrayerAlarmRule(
          id: '1', city: istanbul, weekdays: {5}, prayers: {AlarmPrayer.dhuhr}),
      PrayerAlarmRule(
          id: '2', city: ankara, weekdays: {1}, prayers: {AlarmPrayer.fajr})
    ];
    final plan = planPrayerAlarms(
        rules,
        {
          istanbul.id: [day(friday), day(monday)],
          ankara.id: [day(friday), day(monday, imsak: '04:40')]
        },
        now: DateTime.utc(2026, 9, 3));
    expect(plan.length, 2);
    expect(plan[0].city.id, istanbul.id);
    expect(plan[0].prayer, AlarmPrayer.dhuhr);
    expect(plan[1].city.id, ankara.id);
    expect(plan[1].notifyAt.toUtc(), DateTime.utc(2026, 9, 7, 1, 30));
  });
  test('Friday reminder before midnight still uses Friday selection', () {
    final rule = PrayerAlarmRule(
        id: '1',
        city: istanbul,
        weekdays: {5},
        prayers: {AlarmPrayer.fajr},
        leadMinutes: 30);
    final result = planPrayerAlarms([
      rule
    ], {
      istanbul.id: [day(friday, imsak: '00:10')]
    }, now: DateTime.utc(2026, 9, 3));
    expect(result.single.notifyAt.day, 3);
    expect(result.single.notifyAt.hour, 23);
    expect(result.single.notifyAt.minute, 40);
  });
  test('Duplicates, past times and disabled rules do not schedule extra alarms',
      () {
    final rule = PrayerAlarmRule(
        id: '1', city: istanbul, weekdays: {5}, prayers: {AlarmPrayer.dhuhr});
    expect(
        planPrayerAlarms([
          rule,
          rule,
          rule.withEnabled(false)
        ], {
          istanbul.id: [day(friday)]
        }, now: DateTime.utc(2026, 9, 3))
            .length,
        1);
    expect(
        planPrayerAlarms([
          rule
        ], {
          istanbul.id: [day(friday)]
        }, now: DateTime.utc(2026, 9, 5)),
        isEmpty);
  });
  test('Queue chooses earliest alarms across cities and respects capacity', () {
    final rules = [
      for (final c in [istanbul, ankara])
        PrayerAlarmRule(
            id: c.id,
            city: c,
            weekdays: {1, 2, 3, 4, 5, 6, 7},
            prayers: AlarmPrayer.values.toSet())
    ];
    final result = planPrayerAlarms(
        rules,
        {
          for (final c in [istanbul, ankara])
            c.id: [for (var d = 4; d < 30; d++) day(DateTime(2026, 9, d))]
        },
        now: DateTime.utc(2026, 9, 3),
        limit: 7);
    expect(result.length, 7);
    expect(result.where((a) => a.city.id == ankara.id), isNotEmpty);
    for (var i = 1; i < result.length; i++) {
      expect(result[i].notifyAt.isBefore(result[i - 1].notifyAt), isFalse);
    }
  });
  test('Legacy settings migrate once and removing a rule stays removed',
      () async {
    SharedPreferences.setMockInitialValues({
      'prayer_notifications_city_id': istanbul.id,
      'prayer_notifications_enabled': true,
      'prayer_notifications_lead_minutes': 15
    });
    final service = PrayerAlarmService();
    final rules = await service.loadRules();
    expect(rules.single.city.id, istanbul.id);
    expect(rules.single.weekdays.length, 7);
    expect(rules.single.prayers.length, 5);
    expect(rules.single.leadMinutes, 15);
    await service.saveRules([]);
    expect(await service.loadRules(), isEmpty);
  });
  testWidgets('Alarm editor fits a narrow screen and saves only Friday noon',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    PrayerAlarmRule? saved;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      saved = await Navigator.push<PrayerAlarmRule>(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  PrayerAlarmEditor(initialCity: istanbul)));
                    },
                    child: const Text('Aç'))))));
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Yalnız cuma öğle'));
    await tester.tap(find.text('Yalnız cuma öğle'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Kaydet'));
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(saved!.weekdays, {5});
    expect(saved!.prayers, {AlarmPrayer.dhuhr});
    expect(tester.takeException(), isNull);
  });
}
