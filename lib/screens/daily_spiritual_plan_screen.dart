import 'dart:async';

import 'package:flutter/material.dart';

import '../models/daily_spiritual_plan.dart';
import '../services/daily_spiritual_plan_service.dart';
import '../services/firebase_service.dart' show FirebaseService;
import '../services/smart_goal_reminder_service.dart';
import '../services/achievement_service.dart';
import '../theme/app_theme.dart';
import '../widget_prayer_pending.dart';
import 'dhikr_counter_screen.dart';
import 'juz_list_screen.dart';
import 'quran_reading_plan_screen.dart';
import 'smart_goal_reminder_screen.dart';
import 'achievements_screen.dart';
import 'spiritual_statistics_screen.dart';

class DailySpiritualPlanScreen extends StatefulWidget {
  const DailySpiritualPlanScreen({super.key});

  @override
  State<DailySpiritualPlanScreen> createState() =>
      _DailySpiritualPlanScreenState();
}

class _DailySpiritualPlanScreenState extends State<DailySpiritualPlanScreen> {
  final _service = DailySpiritualPlanService();
  DailySpiritualPlanSummary? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    FirebaseService.logScreenView(screenName: 'screen_daily_spiritual_plan');
    _load();
  }

  Future<void> _load() async {
    final summary = await _service.loadSummary();
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _loading = false;
    });
  }

  Future<void> _openTask(DailyPlanTaskStatus task) async {
    switch (task.type) {
      case DailyPlanTaskType.dailyContent:
        Navigator.pop(context);
        return;
      case DailyPlanTaskType.prayer:
        pendingPrayerWidgetOpen.value = false;
        pendingPrayerWidgetOpen.value = true;
        Navigator.pop(context);
        return;
      case DailyPlanTaskType.dhikr:
        await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(builder: (_) => const DhikrCounterScreen()),
        );
        await _load();
        return;
      case DailyPlanTaskType.quran:
        final openJuz = await Navigator.push<bool>(
          context,
          MaterialPageRoute<bool>(
            builder: (_) => const QuranReadingPlanScreen(),
          ),
        );
        if (openJuz == true && mounted) {
          await Navigator.push<void>(
            context,
            MaterialPageRoute<void>(builder: (_) => const JuzListScreen()),
          );
        }
        await _load();
        return;
      case DailyPlanTaskType.custom:
        final summary = await _service.toggleCustomTask(task.id);
        await SmartGoalReminderService().refreshSchedule();
        unawaited(AchievementService().evaluateAndUnlock(notify: true));
        if (mounted) setState(() => _summary = summary);
        return;
    }
  }

  Future<void> _addCustomTask() async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => const _AddCustomTaskDialog(),
    );
    if (title == null) return;
    try {
      final summary = await _service.addCustomTask(title);
      await SmartGoalReminderService().refreshSchedule();
      if (mounted) setState(() => _summary = summary);
    } on StateError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    }
  }

  Future<void> _deleteCustomTask(DailyPlanTaskStatus task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hedefi kaldır?'),
        content: Text('“${task.title}” günlük planından kaldırılacak.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final summary = await _service.deleteCustomTask(task.id);
    await SmartGoalReminderService().refreshSchedule();
    if (mounted) setState(() => _summary = summary);
  }

  Future<void> _showPlanSettings() async {
    final summary = _summary;
    if (summary == null) return;
    final enabled = Set<String>.from(summary.enabledCoreTaskIds);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.ivory,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, sheetSetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Planı düzenle',
                  style: TextStyle(
                    color: AppTheme.navy,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Günlük planında görmek istediğin temel hedefleri seç.',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
                const SizedBox(height: 12),
                ...[
                  (
                    DailySpiritualPlanService.dailyContentId,
                    'Günün içeriği',
                    Icons.auto_awesome_rounded
                  ),
                  (
                    DailySpiritualPlanService.prayerId,
                    'Namaz hedefi',
                    Icons.mosque_rounded
                  ),
                  (
                    DailySpiritualPlanService.dhikrId,
                    'Zikir hedefi',
                    Icons.touch_app_rounded
                  ),
                  (
                    DailySpiritualPlanService.quranId,
                    'Hatim planı',
                    Icons.auto_stories_rounded
                  ),
                ].map(
                  (item) => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(item.$3, color: AppTheme.emerald),
                    title: Text(item.$2),
                    value: enabled.contains(item.$1),
                    onChanged: (value) async {
                      value ? enabled.add(item.$1) : enabled.remove(item.$1);
                      sheetSetState(() {});
                      final updated = await _service.setCoreTaskEnabled(
                        item.$1,
                        value,
                      );
                      await SmartGoalReminderService().refreshSchedule();
                      if (mounted) setState(() => _summary = updated);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ivory,
      appBar: AppBar(
        title: const Text('Günlük Planım'),
        actions: [
          IconButton(
            tooltip: 'Manevi istatistikler',
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const SpiritualStatisticsScreen(),
              ),
            ),
            icon: const Icon(Icons.bar_chart_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'Plan seçenekleri',
            onSelected: (value) {
              switch (value) {
                case 'achievements':
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const AchievementsScreen(),
                    ),
                  );
                  return;
                case 'reminders':
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const SmartGoalReminderScreen(),
                    ),
                  );
                  return;
                case 'add':
                  unawaited(_addCustomTask());
                  return;
                case 'settings':
                  unawaited(_showPlanSettings());
                  return;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'achievements',
                child: ListTile(
                  leading: Icon(Icons.emoji_events_outlined),
                  title: Text('Başarılar ve rozetler'),
                ),
              ),
              PopupMenuItem(
                value: 'reminders',
                child: ListTile(
                  leading: Icon(Icons.notifications_active_outlined),
                  title: Text('Akıllı hatırlatmalar'),
                ),
              ),
              PopupMenuItem(
                value: 'add',
                child: ListTile(
                  leading: Icon(Icons.add_task_rounded),
                  title: Text('Kişisel hedef ekle'),
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.tune_rounded),
                  title: Text('Planı düzenle'),
                ),
              ),
            ],
          ),
          const SizedBox(width: 5),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _buildContent(_summary!),
            ),
    );
  }

  Widget _buildContent(DailySpiritualPlanSummary summary) {
    final percent = (summary.progress * 100).round();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 34),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.navy, AppTheme.navyContainer],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppTheme.ambientShadow,
          ),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 94,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.square(
                      dimension: 88,
                      child: CircularProgressIndicator(
                        value: summary.progress,
                        strokeWidth: 8,
                        strokeCap: StrokeCap.round,
                        backgroundColor: Colors.white.withValues(alpha: .14),
                        color: AppTheme.gold,
                      ),
                    ),
                    Text(
                      '%$percent',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 17),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.completed
                          ? 'Bugünün planı tamam!'
                          : 'Bugünün manevi planı',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${summary.completedCount}/${summary.tasks.length} hedef • ${summary.currentStreak} günlük seri',
                      style: const TextStyle(color: Color(0xFFD0E4FF)),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department,
                            color: AppTheme.gold, size: 18),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'En iyi seri: ${summary.longestStreak}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.gold,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Bugünkü hedefler',
          style: TextStyle(
            color: AppTheme.navy,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 11),
        if (summary.tasks.isEmpty)
          const _EmptyPlanCard()
        else
          ...summary.tasks.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DailyTaskCard(
                task: task,
                onTap: () => _openTask(task),
                onDelete: task.type == DailyPlanTaskType.custom
                    ? () => _deleteCustomTask(task)
                    : null,
              ),
            ),
          ),
        const SizedBox(height: 7),
        OutlinedButton.icon(
          onPressed: _addCustomTask,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Kişisel hedef ekle'),
        ),
        const SizedBox(height: 18),
        _DailyPlanWeek(days: summary.week),
      ],
    );
  }
}

class _DailyTaskCard extends StatelessWidget {
  const _DailyTaskCard({
    required this.task,
    required this.onTap,
    this.onDelete,
  });

  final DailyPlanTaskStatus task;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  IconData get _icon => switch (task.type) {
        DailyPlanTaskType.dailyContent => Icons.auto_awesome_rounded,
        DailyPlanTaskType.prayer => Icons.mosque_rounded,
        DailyPlanTaskType.dhikr => Icons.touch_app_rounded,
        DailyPlanTaskType.quran => Icons.auto_stories_rounded,
        DailyPlanTaskType.custom => Icons.checklist_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    task.completed ? AppTheme.emerald : AppTheme.mint,
                foregroundColor:
                    task.completed ? Colors.white : AppTheme.emerald,
                child: Icon(task.completed ? Icons.check_rounded : _icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                        color: AppTheme.navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      task.subtitle,
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 11),
                    ),
                    if (!task.completed && task.progress > 0) ...[
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          minHeight: 5,
                          value: task.progress,
                          color: AppTheme.gold,
                          backgroundColor: AppTheme.surfaceLow,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Hedefi kaldır',
                  onPressed: onDelete,
                  icon: const Icon(Icons.close_rounded,
                      color: AppTheme.textMuted),
                )
              else
                const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyPlanWeek extends StatelessWidget {
  const _DailyPlanWeek({required this.days});

  final List<DailyPlanWeekDay> days;
  static const _labels = ['P', 'S', 'Ç', 'P', 'C', 'C', 'P'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.ambientShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bu haftaki plan serisi',
            style: TextStyle(color: AppTheme.navy, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 13),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(days.length, (index) {
              final completed = days[index].completed;
              return Column(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: completed ? AppTheme.emerald : AppTheme.surfaceLow,
                    ),
                    child: Icon(
                      completed ? Icons.check_rounded : Icons.remove_rounded,
                      color: completed ? Colors.white : AppTheme.outline,
                      size: 18,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _labels[index],
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 10),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _EmptyPlanCard extends StatelessWidget {
  const _EmptyPlanCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.mint.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'Planında aktif hedef yok. Üstteki ayar simgesinden temel hedefleri açabilir veya kişisel hedef ekleyebilirsin.',
        style: TextStyle(color: AppTheme.emerald, height: 1.45),
      ),
    );
  }
}

class _AddCustomTaskDialog extends StatefulWidget {
  const _AddCustomTaskDialog();

  @override
  State<_AddCustomTaskDialog> createState() => _AddCustomTaskDialogState();
}

class _AddCustomTaskDialogState extends State<_AddCustomTaskDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _controller.text.trim();
    if (title.isNotEmpty) Navigator.pop(context, title);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.add_task_rounded, color: AppTheme.emerald),
      title: const Text('Kişisel hedef ekle'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 60,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Günlük hedef',
          hintText: 'Örn. Sadaka ver veya dua et',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Ekle'),
        ),
      ],
    );
  }
}
