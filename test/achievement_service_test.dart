import 'dart:convert';

import 'package:daily_dua_hadith/models/achievement.dart';
import 'package:daily_dua_hadith/models/prayer_tracking.dart';
import 'package:daily_dua_hadith/services/achievement_service.dart';
import 'package:daily_dua_hadith/services/prayer_tracking_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('başlangıçta on rozet de kilitlidir', () async {
    final summary = await AchievementService().evaluateAndUnlock(
      now: DateTime(2026, 8, 10),
    );

    expect(summary.achievements.length, 10);
    expect(summary.unlockedCount, 0);
    expect(summary.newlyUnlocked, isEmpty);
  });

  test('günlük okuma ve yedi günlük seri rozetleri açılır', () async {
    SharedPreferences.setMockInitialValues({
      'last_read_date': '2026-08-10',
      'daily_reading_streak': 7,
    });

    final summary = await AchievementService().evaluateAndUnlock(
      now: DateTime(2026, 8, 10),
    );
    final ids =
        summary.newlyUnlocked.map((status) => status.definition.id).toSet();

    expect(ids, contains(AchievementId.firstDailyRead));
    expect(ids, contains(AchievementId.dailyReadWeek));
  });

  test('yedi ardışık namaz hedefi iki namaz rozetini açar', () async {
    final prayer = PrayerTrackingService();
    final start = DateTime(2026, 8, 1);
    await prayer.setDefaultGoal(1, now: start);
    for (var day = 0; day < 7; day++) {
      await prayer.togglePrayer(
        TrackedPrayer.sabah,
        now: start.add(Duration(days: day)),
      );
    }

    final summary = await AchievementService().evaluateAndUnlock(
      now: DateTime(2026, 8, 7),
    );
    final ids =
        summary.newlyUnlocked.map((status) => status.definition.id).toSet();

    expect(ids, contains(AchievementId.firstPrayerGoal));
    expect(ids, contains(AchievementId.prayerWeek));
  });

  test('bin zikir ve ilk zikir hedefi aynı geçmişten hesaplanır', () async {
    SharedPreferences.setMockInitialValues({
      'dhikr_tracking_state_v1': jsonEncode({
        'selectedId': 'subhanallah',
        'targets': {'subhanallah': 33},
        'days': {
          '2026-08-10': {
            'counts': {'subhanallah': 1000},
            'goalMet': true,
          },
        },
      }),
    });

    final summary = await AchievementService().evaluateAndUnlock(
      now: DateTime(2026, 8, 10),
    );
    final ids =
        summary.newlyUnlocked.map((status) => status.definition.id).toSet();

    expect(ids, contains(AchievementId.firstDhikrGoal));
    expect(ids, contains(AchievementId.dhikrThousand));
  });

  test('30 cüz işareti ilk cüz ve ilk hatim rozetlerini açar', () async {
    SharedPreferences.setMockInitialValues({
      'quran_completed_juz_v1': [
        for (var number = 1; number <= 30; number++) '$number',
      ],
    });

    final summary = await AchievementService().evaluateAndUnlock(
      now: DateTime(2026, 8, 10),
    );
    final ids =
        summary.newlyUnlocked.map((status) => status.definition.id).toSet();

    expect(ids, contains(AchievementId.firstJuz));
    expect(ids, contains(AchievementId.firstHatim));
  });

  test('kazanılan rozet ikinci değerlendirmede yeniden bildirilmez', () async {
    SharedPreferences.setMockInitialValues({
      'last_read_date': '2026-08-10',
    });
    final service = AchievementService();

    final first = await service.evaluateAndUnlock(now: DateTime(2026, 8, 10));
    final second = await service.evaluateAndUnlock(now: DateTime(2026, 8, 11));

    expect(first.newlyUnlocked, isNotEmpty);
    expect(second.newlyUnlocked, isEmpty);
    expect(second.unlockedCount, first.unlockedCount);
  });
}
