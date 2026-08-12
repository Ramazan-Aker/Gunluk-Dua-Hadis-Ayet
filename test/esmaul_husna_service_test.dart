import 'package:daily_dua_hadith/models/esmaul_husna_name.dart';
import 'package:daily_dua_hadith/services/esmaul_husna_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Esmaül Hüsna listesi 1-99 arasında eksiksiz ve benzersizdir', () {
    expect(esmaulHusnaNames, hasLength(99));
    expect(esmaulHusnaNames.map((name) => name.number).toSet(), hasLength(99));
    expect(esmaulHusnaNames.first.number, 1);
    expect(esmaulHusnaNames.last.number, 99);
    expect(esmaulHusnaNames.every((name) => name.latin.isNotEmpty), isTrue);
    expect(esmaulHusnaNames.every((name) => name.arabic.isNotEmpty), isTrue);
    expect(esmaulHusnaNames.every((name) => name.meaning.isNotEmpty), isTrue);
  });

  test('favori ve ezber durumu cihazda saklanır', () async {
    final service = EsmaulHusnaService();

    await service.toggleFavorite(2);
    await service.toggleMemorized(2);
    final progress = await service.loadProgress();

    expect(progress.favorites, {2});
    expect(progress.memorized, {2});
    expect(progress.memorizedRatio, closeTo(1 / 99, .0001));

    final updated = await service.toggleFavorite(2);
    expect(updated.favorites, isEmpty);
    expect(updated.memorized, {2});
  });

  test('geçersiz isim numarası kabul edilmez', () async {
    await expectLater(
      EsmaulHusnaService().toggleFavorite(100),
      throwsRangeError,
    );
  });
}
