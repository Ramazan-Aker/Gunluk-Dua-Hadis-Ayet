import 'package:daily_dua_hadith/models/prayer_tracking.dart';
import 'package:daily_dua_hadith/services/prayer_tracking_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('beş vakit tamamlanınca günlük hedef ve seri tamamlanır', () async {
    final service = PrayerTrackingService();
    final now = DateTime(2026, 8, 10, 20);

    for (final prayer in TrackedPrayer.values) {
      await service.togglePrayer(prayer, now: now);
    }

    final summary = await service.loadSummary(now: now);
    expect(summary.today.completedCount, 5);
    expect(summary.today.goalMet, isTrue);
    expect(summary.currentStreak, 1);
  });

  test('bugün tamamlanmadığında dünkü seri gün bitmeden korunur', () async {
    final service = PrayerTrackingService();
    final yesterday = DateTime(2026, 8, 9, 20);
    for (final prayer in TrackedPrayer.values) {
      await service.togglePrayer(prayer, now: yesterday);
    }

    final summary = await service.loadSummary(now: DateTime(2026, 8, 10, 9));
    expect(summary.currentStreak, 1);
    expect(summary.today.completedCount, 0);
  });

  test('hedef değişikliği geçmiş günün hedefini değiştirmez', () async {
    final service = PrayerTrackingService();
    final firstDay = DateTime(2026, 8, 10);
    await service.togglePrayer(TrackedPrayer.sabah, now: firstDay);
    await service.setDefaultGoal(1, now: DateTime(2026, 8, 11));

    final summary = await service.loadSummary(now: DateTime(2026, 8, 11, 12));
    final previous = summary.week.singleWhere(
      (day) => day.date.day == 10,
    );
    expect(previous.goal, 5);
    expect(previous.goalMet, isFalse);
    expect(summary.today.goal, 1);
  });

  test('duraklatılan gün seri hesabını bozmaz', () async {
    final service = PrayerTrackingService();
    final firstDay = DateTime(2026, 8, 8);
    await service.setDefaultGoal(1, now: firstDay);
    await service.togglePrayer(TrackedPrayer.sabah, now: firstDay);
    await service.setTodayPaused(true, now: DateTime(2026, 8, 9));
    await service.togglePrayer(
      TrackedPrayer.ogle,
      now: DateTime(2026, 8, 10),
    );

    final summary = await service.loadSummary(now: DateTime(2026, 8, 10));
    expect(summary.currentStreak, 2);
    expect(summary.longestStreak, 2);
  });

  test('aynı namaza ikinci kez dokunmak kaydı geri alır', () async {
    final service = PrayerTrackingService();
    final now = DateTime(2026, 8, 10);
    await service.togglePrayer(TrackedPrayer.aksam, now: now);
    await service.togglePrayer(TrackedPrayer.aksam, now: now);

    final summary = await service.loadSummary(now: now);
    expect(summary.today.completed, isEmpty);
  });
}
