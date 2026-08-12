import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/dhikr_tracking.dart';
import '../services/dhikr_tracking_service.dart';
import '../services/smart_goal_reminder_service.dart';
import '../services/achievement_service.dart';
import '../services/firebase_service.dart' show FirebaseService;
import '../theme/app_theme.dart';

class DhikrCounterScreen extends StatefulWidget {
  const DhikrCounterScreen({super.key});

  @override
  State<DhikrCounterScreen> createState() => _DhikrCounterScreenState();
}

class _DhikrCounterScreenState extends State<DhikrCounterScreen> {
  final _service = DhikrTrackingService();

  DhikrTrackingSummary? _summary;
  int _displayCount = 0;
  int _displayTodayTotal = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    FirebaseService.logScreenView(screenName: 'screen_dhikr_counter');
    _load();
  }

  Future<void> _load() async {
    final summary = await _service.loadSummary();
    if (!mounted) return;
    _applySummary(summary);
  }

  void _applySummary(DhikrTrackingSummary summary) {
    setState(() {
      _summary = summary;
      _displayCount = summary.count;
      _displayTodayTotal = summary.today.totalCount;
      _loading = false;
    });
  }

  void _increment() {
    final summary = _summary;
    if (summary == null) return;
    final previous = _displayCount;
    setState(() {
      _displayCount++;
      _displayTodayTotal++;
    });
    HapticFeedback.selectionClick();
    if (previous < summary.target && _displayCount >= summary.target) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bugünkü zikir hedefine ulaştın ✨')),
      );
    }
    unawaited(_persistIncrement(summary.option.id));
  }

  Future<void> _persistIncrement(String optionId) async {
    try {
      final result = await _service.increment();
      if (result.count == result.target) {
        unawaited(SmartGoalReminderService().refreshSchedule());
        unawaited(AchievementService().evaluateAndUnlock(notify: true));
      }
      if (!mounted || result.option.id != optionId) return;
      if (result.count >= _displayCount) _applySummary(result);
    } catch (_) {
      if (mounted) await _load();
    }
  }

  Future<void> _selectOption(DhikrOption option) async {
    Navigator.pop(context);
    final result = await _service.selectOption(option.id);
    if (mounted) _applySummary(result);
  }

  Future<void> _showOptions() async {
    final selectedId = _summary?.option.id;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.ivory,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  'Zikir seç',
                  style: TextStyle(
                    color: AppTheme.navy,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...DhikrOption.presets.map(
                (option) => ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  selected: option.id == selectedId,
                  selectedTileColor: AppTheme.mint.withValues(alpha: .48),
                  leading: CircleAvatar(
                    backgroundColor: option.id == selectedId
                        ? AppTheme.emerald
                        : Colors.white,
                    foregroundColor: option.id == selectedId
                        ? Colors.white
                        : AppTheme.emerald,
                    child: Text('${option.defaultTarget}'),
                  ),
                  title: Text(
                    option.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    option.arabic,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontSize: 17),
                  ),
                  trailing: option.id == selectedId
                      ? const Icon(Icons.check_circle, color: AppTheme.emerald)
                      : null,
                  onTap: () => _selectOption(option),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editTarget() async {
    final summary = _summary;
    if (summary == null) return;
    final controller = TextEditingController(text: '${summary.target}');
    final target = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.flag_rounded, color: AppTheme.gold),
        title: const Text('Günlük hedef'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 4,
          decoration: const InputDecoration(
            labelText: 'Hedef sayısı',
            hintText: 'Örneğin 33 veya 100',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value >= 1 && value <= 9999) {
                Navigator.pop(dialogContext, value);
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (target == null) return;
    final result = await _service.setTarget(target);
    unawaited(SmartGoalReminderService().refreshSchedule());
    if (mounted) _applySummary(result);
  }

  Future<void> _reset() async {
    if (_summary == null || _displayCount == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.refresh_rounded),
        title: const Text('Sayacı sıfırla?'),
        content: const Text(
          'Seçili zikrin bugünkü sayacı sıfırlanacak. Kazanılmış günlük başarı ve seri korunur.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sıfırla'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await _service.resetCurrent();
    unawaited(SmartGoalReminderService().refreshSchedule());
    if (mounted) _applySummary(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ivory,
      appBar: AppBar(
        title: const Text('Zikirmatik'),
        actions: [
          IconButton(
            tooltip: 'Sayacı sıfırla',
            onPressed: _displayCount == 0 ? null : _reset,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(_summary!),
    );
  }

  Widget _buildContent(DhikrTrackingSummary summary) {
    final progress = (_displayCount / summary.target).clamp(0.0, 1.0);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 34),
      children: [
        _StatsRow(
          streak: summary.currentStreak,
          todayTotal: _displayTodayTotal,
          longestStreak: summary.longestStreak,
        ),
        const SizedBox(height: 16),
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _showOptions,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.navy,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.navy.withValues(alpha: .18),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.option.arabic,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          color: AppTheme.gold,
                          fontSize: 27,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        summary.option.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        summary.option.meaning,
                        style: const TextStyle(
                          color: Color(0xFFD6E5EF),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.unfold_more_rounded, color: AppTheme.mint),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Semantics(
            button: true,
            label: '${summary.option.title} sayacını artır',
            value: '$_displayCount / ${summary.target}',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _increment,
              child: SizedBox.square(
                dimension: 214,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.square(
                      dimension: 204,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 11,
                        strokeCap: StrokeCap.round,
                        backgroundColor:
                            AppTheme.outline.withValues(alpha: .25),
                        color: AppTheme.gold,
                      ),
                    ),
                    Container(
                      width: 174,
                      height: 174,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppTheme.emerald, Color(0xFF214E44)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.emerald.withValues(alpha: .27),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$_displayCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 47,
                              height: 1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 9),
                          const Text(
                            'DOKUN',
                            style: TextStyle(
                              color: AppTheme.mint,
                              fontSize: 12,
                              letterSpacing: 1.7,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _displayCount >= summary.target
                  ? 'Hedef tamamlandı'
                  : '${summary.target - _displayCount} zikir kaldı',
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 7),
            TextButton.icon(
              onPressed: _editTarget,
              icon: const Icon(Icons.edit_rounded, size: 17),
              label: Text('Hedef ${summary.target}'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _WeeklyProgress(days: summary.week),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.mint.withValues(alpha: .32),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock_outline_rounded, color: AppTheme.emerald),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Zikir sayılarınız yalnızca cihazınızda saklanır.',
                  style: TextStyle(color: AppTheme.emerald, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.streak,
    required this.todayTotal,
    required this.longestStreak,
  });

  final int streak;
  final int todayTotal;
  final int longestStreak;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(
            icon: Icons.local_fire_department, value: '$streak', label: 'Seri'),
        const SizedBox(width: 8),
        _StatCard(
            icon: Icons.touch_app_rounded,
            value: '$todayTotal',
            label: 'Bugün'),
        const SizedBox(width: 8),
        _StatCard(
            icon: Icons.emoji_events_outlined,
            value: '$longestStreak',
            label: 'En iyi'),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppTheme.ambientShadow,
        ),
        child: Column(
          children: [
            Icon(icon, size: 19, color: AppTheme.gold),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                color: AppTheme.navy,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(label,
                style:
                    const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _WeeklyProgress extends StatelessWidget {
  const _WeeklyProgress({required this.days});

  final List<DhikrDayProgress> days;

  static const _labels = ['P', 'S', 'Ç', 'P', 'C', 'C', 'P'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.ambientShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bu hafta',
            style: TextStyle(
              color: AppTheme.navy,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(days.length, (index) {
              final completed = days[index].goalMet;
              return Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 33,
                    height: 33,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: completed ? AppTheme.emerald : AppTheme.surfaceLow,
                      border: Border.all(
                        color: completed ? AppTheme.emerald : AppTheme.outline,
                      ),
                    ),
                    child: Icon(
                      completed ? Icons.check_rounded : Icons.circle_outlined,
                      size: completed ? 19 : 8,
                      color: completed ? Colors.white : AppTheme.outline,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _labels[index],
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
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
