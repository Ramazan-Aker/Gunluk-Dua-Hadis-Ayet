import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/achievement.dart';
import 'daily_spiritual_plan_service.dart';
import 'dhikr_tracking_service.dart';
import 'notification_service.dart';
import 'prayer_tracking_service.dart';
import 'quran_progress_service.dart';

class AchievementService {
  static const _unlockedKey = 'achievements_unlocked_v1';

  Future<AchievementSummary> evaluateAndUnlock({
    DateTime? now,
    bool notify = false,
  }) async {
    final currentDate = now ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final prayerHistory = await PrayerTrackingService().loadHistory();
    final dhikrHistory = await DhikrTrackingService().loadHistory(
      forceReload: true,
    );
    final completedJuz = await QuranProgressService().completedJuz();
    final dailyPlanDates = await DailySpiritualPlanService().achievementDates();
    final unlocked = _readUnlocked(prefs);

    final prayerGoalDays = prayerHistory
        .where((day) => day.goalMet)
        .map((day) => day.date)
        .toSet();
    final dhikrGoalDays =
        dhikrHistory.where((day) => day.goalMet).map((day) => day.date).toSet();
    final dhikrTotal = dhikrHistory.fold<int>(
      0,
      (total, day) => total + day.totalCount,
    );
    final dailyReadStreak = prefs.getInt('daily_reading_streak') ?? 0;
    final hasDailyRead = prefs.getString('last_read_date') != null;

    final values = <AchievementId, int>{
      AchievementId.firstDailyRead: hasDailyRead ? 1 : 0,
      AchievementId.dailyReadWeek: dailyReadStreak,
      AchievementId.firstPrayerGoal: prayerGoalDays.length,
      AchievementId.prayerWeek: _longestStreak(prayerGoalDays),
      AchievementId.firstDhikrGoal: dhikrGoalDays.length,
      AchievementId.dhikrThousand: dhikrTotal,
      AchievementId.firstJuz: completedJuz.length,
      AchievementId.firstHatim: completedJuz.length,
      AchievementId.firstDailyPlan: dailyPlanDates.length,
      AchievementId.dailyPlanWeek: _longestStreak(dailyPlanDates),
    };
    final newlyUnlockedIds = <AchievementId>[];
    for (final definition in definitions) {
      if ((values[definition.id] ?? 0) < definition.target) continue;
      if (unlocked.containsKey(definition.id)) continue;
      unlocked[definition.id] = currentDate;
      newlyUnlockedIds.add(definition.id);
    }
    if (newlyUnlockedIds.isNotEmpty) {
      await _writeUnlocked(prefs, unlocked);
    }

    final statuses = [
      for (final definition in definitions)
        AchievementStatus(
          definition: definition,
          current: values[definition.id] ?? 0,
          unlockedAt: unlocked[definition.id],
        ),
    ];
    final newlyUnlocked = statuses
        .where((status) => newlyUnlockedIds.contains(status.definition.id))
        .toList();
    if (notify) {
      for (final status in newlyUnlocked) {
        try {
          await NotificationService().showNotification(
            notificationId: 21000 + status.definition.id.index,
            title: 'Yeni rozet: ${status.definition.title}',
            body: status.definition.description,
          );
        } catch (_) {}
      }
    }
    return AchievementSummary(
      achievements: statuses,
      newlyUnlocked: newlyUnlocked,
    );
  }

  Map<AchievementId, DateTime> _readUnlocked(SharedPreferences prefs) {
    final raw = prefs.getString(_unlockedKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final result = <AchievementId, DateTime>{};
      for (final entry in decoded.entries) {
        final id = AchievementId.values
            .where((value) => value.name == entry.key)
            .firstOrNull;
        final date = DateTime.tryParse(entry.value as String? ?? '');
        if (id != null && date != null) result[id] = date;
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeUnlocked(
    SharedPreferences prefs,
    Map<AchievementId, DateTime> unlocked,
  ) async {
    await prefs.setString(
      _unlockedKey,
      jsonEncode({
        for (final entry in unlocked.entries)
          entry.key.name: entry.value.toIso8601String(),
      }),
    );
  }

  int _longestStreak(Set<DateTime> rawDates) {
    if (rawDates.isEmpty) return 0;
    final dates = rawDates
        .map((date) => DateTime(date.year, date.month, date.day))
        .toSet()
        .toList()
      ..sort();
    var longest = 1;
    var current = 1;
    for (var index = 1; index < dates.length; index++) {
      if (dates[index].difference(dates[index - 1]).inDays == 1) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 1;
      }
    }
    return longest;
  }

  static const definitions = <AchievementDefinition>[
    AchievementDefinition(
      id: AchievementId.firstDailyRead,
      title: 'İlk Adım',
      description: 'İlk günlük ayet, dua veya hadis içeriğini okudun.',
      target: 1,
      symbol: '✨',
    ),
    AchievementDefinition(
      id: AchievementId.dailyReadWeek,
      title: 'Bir Hafta Birlikte',
      description: 'Günlük içerik serisini 7 güne ulaştırdın.',
      target: 7,
      symbol: '📖',
    ),
    AchievementDefinition(
      id: AchievementId.firstPrayerGoal,
      title: 'Vakit Bilinci',
      description: 'İlk günlük namaz hedefini tamamladın.',
      target: 1,
      symbol: '🕌',
    ),
    AchievementDefinition(
      id: AchievementId.prayerWeek,
      title: 'Namaz Serisi',
      description: 'Namaz hedefini 7 gün art arda tamamladın.',
      target: 7,
      symbol: '🌙',
    ),
    AchievementDefinition(
      id: AchievementId.firstDhikrGoal,
      title: 'İlk Zikir Hedefi',
      description: 'İlk günlük zikir hedefini tamamladın.',
      target: 1,
      symbol: '📿',
    ),
    AchievementDefinition(
      id: AchievementId.dhikrThousand,
      title: 'Bin Zikir',
      description: 'Toplam 1000 zikre ulaştın.',
      target: 1000,
      symbol: '💫',
    ),
    AchievementDefinition(
      id: AchievementId.firstJuz,
      title: 'İlk Cüz',
      description: 'İlk cüzü okundu olarak işaretledin.',
      target: 1,
      symbol: '📗',
    ),
    AchievementDefinition(
      id: AchievementId.firstHatim,
      title: 'İlk Hatim',
      description: 'Kur’an-ı Kerim’in 30 cüzünü tamamladın.',
      target: 30,
      symbol: '🏆',
    ),
    AchievementDefinition(
      id: AchievementId.firstDailyPlan,
      title: 'Dengeli Bir Gün',
      description: 'İlk Günlük Manevi Planını tamamladın.',
      target: 1,
      symbol: '✅',
    ),
    AchievementDefinition(
      id: AchievementId.dailyPlanWeek,
      title: 'Denge Serisi',
      description: 'Günlük Manevi Planını 7 gün art arda tamamladın.',
      target: 7,
      symbol: '🔥',
    ),
  ];
}
