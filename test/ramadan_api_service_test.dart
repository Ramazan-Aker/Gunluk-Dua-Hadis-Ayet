import 'package:daily_dua_hadith/services/ramadan_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RamadanApiService date ranges', () {
    final service = RamadanApiService();

    test('shows a rolling 31-day range outside Ramadan', () {
      final range = service.getPrayerTimesDateRange(
        DateTime(2026, 7, 26, 15, 30),
      );

      expect(range['start'], DateTime(2026, 7, 26));
      expect(range['end'], DateTime(2026, 8, 25));
      expect(service.isRamadanDate(DateTime(2026, 7, 26)), isFalse);
    });

    test('shows the full imsakiye during Ramadan 2026', () {
      final range = service.getPrayerTimesDateRange(
        DateTime(2026, 3, 1, 12),
      );

      expect(range['start'], DateTime(2026, 2, 19));
      expect(range['end'], DateTime(2026, 3, 19));
    });

    test('Ramadan boundaries are inclusive', () {
      expect(service.isRamadanDate(DateTime(2026, 2, 19)), isTrue);
      expect(service.isRamadanDate(DateTime(2026, 3, 19, 23, 59)), isTrue);
      expect(service.isRamadanDate(DateTime(2026, 2, 18)), isFalse);
      expect(service.isRamadanDate(DateTime(2026, 3, 20)), isFalse);
    });

    test('uses official 2028 dates and does not guess unknown years', () {
      expect(service.isRamadanDate(DateTime(2028, 1, 28)), isTrue);
      expect(service.isRamadanDate(DateTime(2028, 2, 25)), isTrue);

      final unknownYearRange = service.getPrayerTimesDateRange(
        DateTime(2029, 3, 10),
      );
      expect(unknownYearRange['start'], DateTime(2029, 3, 10));
      expect(unknownYearRange['end'], DateTime(2029, 4, 9));
    });
  });
}
