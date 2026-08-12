import 'package:daily_dua_hadith/models/dhikr_tracking.dart';
import 'package:daily_dua_hadith/services/dhikr_tracking_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('hızlı art arda dokunuşlarda hiçbir zikir kaybolmaz', () async {
    final service = DhikrTrackingService();
    final date = DateTime(2026, 8, 10, 12);

    await Future.wait(
      List.generate(40, (_) => service.increment(now: date)),
    );
    final summary = await service.loadSummary(now: date);

    expect(summary.count, 40);
    expect(summary.today.totalCount, 40);
    expect(summary.today.goalMet, isTrue);
    expect(summary.currentStreak, 1);
  });

  test('sayaç sıfırlanınca kazanılmış günlük başarı korunur', () async {
    final service = DhikrTrackingService();
    final date = DateTime(2026, 8, 10);
    await service.setTarget(3, now: date);
    await service.increment(now: date);
    await service.increment(now: date);
    await service.increment(now: date);

    final reset = await service.resetCurrent(now: date);

    expect(reset.count, 0);
    expect(reset.today.goalMet, isTrue);
    expect(reset.currentStreak, 1);
  });

  test('zikirlerin sayaçları ve hedefleri birbirinden bağımsızdır', () async {
    final service = DhikrTrackingService();
    final date = DateTime(2026, 8, 10);
    await service.setTarget(10, now: date);
    await service.increment(now: date);
    await service.increment(now: date);

    final salavat = DhikrOption.fromId('salavat');
    var summary = await service.selectOption(salavat.id, now: date);
    expect(summary.count, 0);
    expect(summary.target, salavat.defaultTarget);

    await service.increment(now: date);
    summary = await service.selectOption('subhanallah', now: date);
    expect(summary.count, 2);
    expect(summary.target, 10);
    expect(summary.today.totalCount, 3);
  });

  test('bugün tamamlanmadıysa dünkü seri gün bitmeden devam eder', () async {
    final service = DhikrTrackingService();
    final yesterday = DateTime(2026, 8, 9);
    final today = DateTime(2026, 8, 10);
    await service.setTarget(2, now: yesterday);
    await service.increment(now: yesterday);
    await service.increment(now: yesterday);

    final summary = await service.loadSummary(now: today);

    expect(summary.today.goalMet, isFalse);
    expect(summary.currentStreak, 1);
  });

  test('geçersiz özel hedef reddedilir', () async {
    final service = DhikrTrackingService();

    expect(() => service.setTarget(0), throwsArgumentError);
    expect(() => service.setTarget(10000), throwsArgumentError);
  });
}
