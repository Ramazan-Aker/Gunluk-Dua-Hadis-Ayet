import 'package:daily_dua_hadith/models/prayer_times.dart';
import 'package:daily_dua_hadith/services/ramadan_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Diyanet alanları eksiksiz ve sıralı bir vakit satırı üretir', () {
    final result = PrayerTimes.tryFromJson(
      const {
        'imsak': '04:11',
        'gunes': '05:48',
        'ogle': '12:59',
        'ikindi': '16:49',
        'aksam': '20:00',
        'yatsi': '21:30',
      },
      DateTime(2026, 8, 10),
    );

    expect(result, isNotNull);
    expect(result!.imsak, '04:11');
    expect(result.yatsi, '21:30');
    expect(result.hasChronologicalOrder, isTrue);
  });

  test('İngilizce API alan adları da desteklenir', () {
    final result = PrayerTimes.tryFromJson(
      const {
        'fajr': '04:22',
        'sun': '06:02',
        'dhuhr': '13:15',
        'asr': '17:06',
        'maghrib': '20:18',
        'isha': '21:50',
      },
      DateTime(2026, 8, 10),
    );

    expect(result, isNotNull);
    expect(result!.aksam, '20:18');
  });

  test('eksik veya geçersiz saat 00:00 olarak gösterilmez', () {
    expect(
      PrayerTimes.tryFromJson(
        const {
          'imsak': '04:11',
          'gunes': '05:48',
          'ogle': '12:59',
          'ikindi': '16:49',
          'aksam': '20:00',
        },
        DateTime(2026, 8, 10),
      ),
      isNull,
    );
    expect(
      PrayerTimes.tryFromJson(
        const {
          'imsak': '24:80',
          'gunes': '05:48',
          'ogle': '12:59',
          'ikindi': '16:49',
          'aksam': '20:00',
          'yatsi': '21:30',
        },
        DateTime(2026, 8, 10),
      ),
      isNull,
    );
  });

  test('kronolojik olmayan vakit satırı reddedilir', () {
    final result = PrayerTimes.tryFromJson(
      const {
        'imsak': '04:11',
        'gunes': '05:48',
        'ogle': '12:59',
        'ikindi': '12:30',
        'aksam': '20:00',
        'yatsi': '21:30',
      },
      DateTime(2026, 8, 10),
    );

    expect(result, isNull);
  });

  test('UTC ekli API tarihi saat diliminden bağımsız takvim günü olarak okunur',
      () {
    final date = RamadanApiService.parseApiCalendarDate(
      '2026-08-10T00:00:00.000Z',
    );

    expect(date, DateTime(2026, 8, 10));
    expect(
      RamadanApiService.parseApiCalendarDate('2026-02-30T00:00:00.000Z'),
      isNull,
    );
  });
}
