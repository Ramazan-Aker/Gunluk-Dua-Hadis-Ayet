import 'package:daily_dua_hadith/models/kaza_prayer_tracking.dart';
import 'package:daily_dua_hadith/services/kaza_prayer_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('borç eklenir ve kılındıkça azaltılır', () async {
    final service = KazaPrayerService();

    var summary = await service.addDebt(KazaPrayerType.fajr, 10);
    expect(summary.debtFor(KazaPrayerType.fajr), 10);
    expect(summary.totalDebt, 10);

    summary = await service.markPerformed(KazaPrayerType.fajr, 3);
    expect(summary.debtFor(KazaPrayerType.fajr), 7);
    expect(summary.totalPerformed, 3);
    expect(summary.history, hasLength(2));
  });

  test('kılınan miktar mevcut borcun altına düşmez', () async {
    final service = KazaPrayerService();
    await service.addDebt(KazaPrayerType.isha, 2);

    final summary = await service.markPerformed(KazaPrayerType.isha, 10);

    expect(summary.debtFor(KazaPrayerType.isha), 0);
    expect(summary.totalPerformed, 2);
  });

  test('tüm namaz türleri ayrı saklanır', () async {
    final service = KazaPrayerService();
    for (final type in KazaPrayerType.values) {
      await service.addDebt(type, type.index + 1);
    }

    final restored = await KazaPrayerService().loadSummary();
    for (final type in KazaPrayerType.values) {
      expect(restored.debtFor(type), type.index + 1);
    }
  });

  test('geçersiz miktar reddedilir', () {
    expect(
      () => KazaPrayerService().addDebt(KazaPrayerType.fajr, 0),
      throwsArgumentError,
    );
  });
}
