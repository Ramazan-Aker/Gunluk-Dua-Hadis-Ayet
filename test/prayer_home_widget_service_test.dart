import 'package:daily_dua_hadith/models/prayer_times.dart';
import 'package:daily_dua_hadith/services/prayer_home_widget_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final times = [
    PrayerTimes(
      date: DateTime(2026, 8, 10),
      imsak: '04:21',
      gunes: '05:58',
      ogle: '13:12',
      ikindi: '17:03',
      aksam: '20:14',
      yatsi: '21:43',
    ),
    PrayerTimes(
      date: DateTime(2026, 8, 11),
      imsak: '04:23',
      gunes: '06:00',
      ogle: '13:12',
      ikindi: '17:02',
      aksam: '20:12',
      yatsi: '21:41',
    ),
  ];

  test('widget programı güneşi hariç tutup beş vakit üretir', () {
    final schedule = PrayerHomeWidgetService.buildSchedule(times);
    expect(schedule, hasLength(10));
    expect(schedule.first.name, 'Sabah');
    expect(schedule.first.time, '04:21');
    expect(schedule.where((moment) => moment.name == 'Güneş'), isEmpty);
  });

  test('sıradaki vakit doğru seçilir', () {
    final schedule = PrayerHomeWidgetService.buildSchedule(times);
    final next = PrayerHomeWidgetService.nextMoment(
      schedule,
      now: DateTime(2026, 8, 10, 18),
    );
    expect(next?.name, 'Akşam');
    expect(next?.time, '20:14');
  });

  test('geçersiz saat widget programına alınmaz', () {
    final invalid = PrayerTimes(
      date: DateTime(2026, 8, 10),
      imsak: '25:99',
      gunes: '05:58',
      ogle: '13:12',
      ikindi: '17:03',
      aksam: '20:14',
      yatsi: '21:43',
    );
    final schedule = PrayerHomeWidgetService.buildSchedule([invalid]);
    expect(schedule, hasLength(4));
  });
}
