import 'package:flutter/material.dart';

import '../models/smart_goal_reminder.dart';
import '../services/notification_service.dart';
import '../services/smart_goal_reminder_service.dart';
import '../theme/app_theme.dart';

class SmartGoalReminderScreen extends StatefulWidget {
  const SmartGoalReminderScreen({super.key});

  @override
  State<SmartGoalReminderScreen> createState() =>
      _SmartGoalReminderScreenState();
}

class _SmartGoalReminderScreenState extends State<SmartGoalReminderScreen> {
  final _service = SmartGoalReminderService();
  final _notifications = NotificationService();
  List<SmartGoalReminderSetting> _settings = const [];
  bool _loading = true;
  SmartGoalType? _savingType;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await _service.loadSettings();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _loading = false;
    });
  }

  Future<void> _toggle(
    SmartGoalReminderSetting setting,
    bool enabled,
  ) async {
    if (enabled) {
      final granted = await _notifications.requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bildirim izni verilmeden hatırlatma açılamaz.'),
            ),
          );
        }
        return;
      }
    }
    await _save(setting.copyWith(enabled: enabled));
  }

  Future<void> _pickTime(SmartGoalReminderSetting setting) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: setting.hour, minute: setting.minute),
      helpText: '${setting.type.title} saatini seç',
    );
    if (selected == null) return;
    await _save(
      setting.copyWith(hour: selected.hour, minute: selected.minute),
    );
  }

  Future<void> _save(SmartGoalReminderSetting setting) async {
    setState(() => _savingType = setting.type);
    final updated = await _service.updateSetting(setting);
    if (!mounted) return;
    setState(() {
      _settings = updated;
      _savingType = null;
    });
  }

  Future<void> _showTestNotification() async {
    final granted = await _notifications.requestPermission();
    if (!granted || !mounted) return;
    await _notifications.showNotification(
      title: 'Akıllı Hatırlatma',
      body: 'Hedef bildirimlerin bu şekilde görünecek.',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test bildirimi gönderildi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ivory,
      appBar: AppBar(title: const Text('Akıllı Hatırlatmalar')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 34),
              children: [
                Container(
                  padding: const EdgeInsets.all(19),
                  decoration: BoxDecoration(
                    color: AppTheme.navy,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: AppTheme.ambientShadow,
                  ),
                  child: const Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppTheme.emerald,
                        foregroundColor: AppTheme.gold,
                        child: Icon(Icons.notifications_active_rounded),
                      ),
                      SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Yalnızca seçtiğin hedefler',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Her hedefin saatini ayrı belirleyebilirsin. Tamamlanan hedefin bugünkü bildirimi ertelenir.',
                              style: TextStyle(
                                color: Color(0xFFD0E4FF),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ..._settings.map(
                  (setting) => Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: _ReminderSettingCard(
                      setting: setting,
                      saving: _savingType == setting.type,
                      onToggle: (value) => _toggle(setting, value),
                      onTimeTap: () => _pickTime(setting),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                OutlinedButton.icon(
                  onPressed: _showTestNotification,
                  icon: const Icon(Icons.notification_add_outlined),
                  label: const Text('Test bildirimi gönder'),
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.mint.withValues(alpha: .34),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: AppTheme.emerald, size: 20),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Bunlar namaz vakti bildirimlerinden bağımsızdır. Telefonun pil optimizasyonu bazı cihazlarda hatırlatmaları geciktirebilir.',
                          style: TextStyle(
                            color: AppTheme.emerald,
                            fontSize: 11,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ReminderSettingCard extends StatelessWidget {
  const _ReminderSettingCard({
    required this.setting,
    required this.saving,
    required this.onToggle,
    required this.onTimeTap,
  });

  final SmartGoalReminderSetting setting;
  final bool saving;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTimeTap;

  IconData get _icon => switch (setting.type) {
        SmartGoalType.prayer => Icons.mosque_rounded,
        SmartGoalType.dhikr => Icons.touch_app_rounded,
        SmartGoalType.quran => Icons.auto_stories_rounded,
        SmartGoalType.dailyPlan => Icons.checklist_rounded,
      };

  String get _time => '${setting.hour.toString().padLeft(2, '0')}:'
      '${setting.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.ambientShadow,
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor:
                setting.enabled ? AppTheme.mint : AppTheme.surfaceLow,
            foregroundColor:
                setting.enabled ? AppTheme.emerald : AppTheme.textMuted,
            child: Icon(_icon),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  setting.type.title,
                  style: const TextStyle(
                    color: AppTheme.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  setting.type.description,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 7),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: setting.enabled && !saving ? onTimeTap : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule_rounded,
                            size: 16, color: AppTheme.gold),
                        const SizedBox(width: 5),
                        Text(
                          _time,
                          style: TextStyle(
                            color: setting.enabled
                                ? AppTheme.emerald
                                : AppTheme.textMuted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          saving
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Switch(value: setting.enabled, onChanged: onToggle),
        ],
      ),
    );
  }
}
