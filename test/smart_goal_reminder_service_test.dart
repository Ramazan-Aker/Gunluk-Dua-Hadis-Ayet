import 'package:daily_dua_hadith/models/smart_goal_reminder.dart';
import 'package:daily_dua_hadith/services/smart_goal_reminder_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('dört akıllı hatırlatma varsayılan olarak kapalıdır', () async {
    final settings = await SmartGoalReminderService().loadSettings();

    expect(settings.length, 4);
    expect(settings.every((setting) => !setting.enabled), isTrue);
    expect(settings.map((setting) => setting.type).toSet(),
        SmartGoalType.values.toSet());
  });

  test('kullanıcının seçtiği saat kalıcı olarak saklanır', () async {
    final service = SmartGoalReminderService();
    final original = (await service.loadSettings()).first;
    await service.updateSetting(
      original.copyWith(enabled: true, hour: 22, minute: 15),
    );

    final restored = (await SmartGoalReminderService().loadSettings()).first;
    expect(restored.enabled, isTrue);
    expect(restored.hour, 22);
    expect(restored.minute, 15);
  });

  test('hedef tamamlandıysa bugünkü hatırlatma yarına ertelenir', () {
    const setting = SmartGoalReminderSetting(
      type: SmartGoalType.dhikr,
      enabled: true,
      hour: 20,
      minute: 30,
    );

    final next = SmartGoalReminderService.nextReminderAt(
      setting: setting,
      now: DateTime(2026, 8, 10, 12),
      completedToday: true,
    );

    expect(next, DateTime(2026, 8, 11, 20, 30));
  });

  test('saat geçtiyse tamamlanmamış hedef de yarına planlanır', () {
    const setting = SmartGoalReminderSetting(
      type: SmartGoalType.prayer,
      enabled: true,
      hour: 21,
      minute: 0,
    );

    final next = SmartGoalReminderService.nextReminderAt(
      setting: setting,
      now: DateTime(2026, 8, 10, 22),
      completedToday: false,
    );

    expect(next, DateTime(2026, 8, 11, 21));
  });
}
