import 'dart:async';

import 'package:flutter/material.dart';

import '../models/quran_reading_plan.dart';
import '../services/firebase_service.dart' show FirebaseService;
import '../services/quran_progress_service.dart';
import '../services/quran_reading_plan_service.dart';
import '../services/smart_goal_reminder_service.dart';
import '../theme/app_theme.dart';

class QuranReadingPlanScreen extends StatefulWidget {
  const QuranReadingPlanScreen({
    super.key,
    this.allowOpenJuzList = true,
  });

  final bool allowOpenJuzList;

  @override
  State<QuranReadingPlanScreen> createState() => _QuranReadingPlanScreenState();
}

class _QuranReadingPlanScreenState extends State<QuranReadingPlanScreen> {
  final _planService = QuranReadingPlanService();
  final _progressService = QuranProgressService();

  QuranReadingPlanSummary? _summary;
  Set<int> _completed = {};
  DateTime _targetDate = DateTime.now().add(const Duration(days: 29));
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    FirebaseService.logScreenView(screenName: 'screen_quran_reading_plan');
    _load();
  }

  Future<void> _load() async {
    final summary = await _planService.loadSummary();
    final completed = await _progressService.completedJuz();
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _completed = completed;
      _loading = false;
    });
  }

  int get _selectedDays =>
      _targetDate.difference(_dateOnly(DateTime.now())).inDays + 1;

  Future<void> _pickSetupDate() async {
    final today = _dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate.isBefore(today) ? today : _targetDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
      helpText: 'Hatim bitiş tarihini seç',
    );
    if (picked != null && mounted) setState(() => _targetDate = picked);
  }

  Future<void> _startPlan() async {
    var resetProgress = false;
    if (_completed.length == 30) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.auto_stories_rounded, color: AppTheme.gold),
          title: const Text('Yeni hatim başlat?'),
          content: const Text(
            '30 cüzün okundu işaretleri temizlenecek ve yeni hatim planı sıfırdan başlayacak.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Yeni hatim başlat'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      resetProgress = true;
    }
    setState(() => _saving = true);
    try {
      final summary = await _planService.createPlan(
        targetDate: _targetDate,
        resetProgress: resetProgress,
      );
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _completed = summary.completedJuz;
        _saving = false;
      });
      unawaited(SmartGoalReminderService().refreshSchedule());
      FirebaseService.logEvent(
        name: 'quran_reading_plan_created',
        parameters: {'duration_days': summary.totalDays},
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hatim planı oluşturulamadı.')),
      );
    }
  }

  Future<void> _editTargetDate() async {
    final summary = _summary;
    if (summary == null) return;
    final today = _dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: summary.plan.targetDate.isBefore(today)
          ? today
          : summary.plan.targetDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
      helpText: 'Yeni bitiş tarihini seç',
    );
    if (picked == null) return;
    final updated = await _planService.updateTargetDate(picked);
    unawaited(SmartGoalReminderService().refreshSchedule());
    if (mounted) setState(() => _summary = updated);
  }

  Future<void> _deletePlan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.flag_outlined),
        title: const Text('Hatim planını kaldır?'),
        content: const Text(
          'Yalnızca plan kaldırılır. Okundu olarak işaretlediğiniz cüzler korunur.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Planı kaldır'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _planService.deletePlan();
    unawaited(SmartGoalReminderService().refreshSchedule());
    if (!mounted) return;
    setState(() {
      _summary = null;
      _targetDate = DateTime.now().add(const Duration(days: 29));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ivory,
      appBar: AppBar(
        title: const Text('Hatim Planım'),
        actions: [
          if (_summary != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'date') _editTargetDate();
                if (value == 'delete') _deletePlan();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: 'date', child: Text('Bitiş tarihini değiştir')),
                PopupMenuItem(value: 'delete', child: Text('Planı kaldır')),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _summary == null
              ? _buildSetup()
              : _buildPlan(_summary!),
    );
  }

  Widget _buildSetup() {
    final remaining = 30 - _completed.length;
    final daily = remaining == 0 ? 0 : (remaining / _selectedDays).ceil();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppTheme.navy,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.navy.withValues(alpha: .18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Column(
            children: [
              Icon(Icons.auto_stories_rounded, color: AppTheme.gold, size: 44),
              SizedBox(height: 12),
              Text(
                'Kendi hızında hatim yap',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 7),
              Text(
                'Bitiş tarihini seç; uygulama günlük cüz hedefini ve ilerlemeni hesaplasın.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFD0E4FF), height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _InfoStrip(
          icon: Icons.check_circle_outline_rounded,
          title: '${_completed.length}/30 cüz tamamlandı',
          subtitle: remaining == 0
              ? 'Yeni bir hatme başlamaya hazırsın.'
              : 'Plan kalan $remaining cüz üzerinden hazırlanacak.',
        ),
        const SizedBox(height: 20),
        const Text(
          'Ne kadar sürede tamamlamak istersin?',
          style: TextStyle(
            color: AppTheme.navy,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [30, 60, 90, 120].map((days) {
            final selected = _selectedDays == days;
            return ChoiceChip(
              selected: selected,
              label: Text('$days gün'),
              onSelected: (_) => setState(() {
                _targetDate =
                    _dateOnly(DateTime.now()).add(Duration(days: days - 1));
              }),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickSetupDate,
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text('Bitiş: ${_formatDate(_targetDate)}'),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.mint.withValues(alpha: .38),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppTheme.emerald,
                foregroundColor: Colors.white,
                child: Icon(Icons.flag_rounded),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  remaining == 0
                      ? 'Yeni planda günlük yaklaşık ${30 / _selectedDays < 1 ? 1 : (30 / _selectedDays).ceil()} cüz okuyacaksın.'
                      : 'Günde yaklaşık $daily cüz okuyarak ${_formatDate(_targetDate)} tarihinde tamamlayabilirsin.',
                  style: const TextStyle(
                    color: AppTheme.emerald,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _saving ? null : _startPlan,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow_rounded),
          label: Text(
              _completed.length == 30 ? 'Yeni hatim başlat' : 'Planı başlat'),
        ),
      ],
    );
  }

  Widget _buildPlan(QuranReadingPlanSummary summary) {
    final percentage = (summary.progress * 100).round();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
        children: [
          Container(
            padding: const EdgeInsets.all(21),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.navy, AppTheme.navyContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppTheme.ambientShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_stories_rounded,
                        color: AppTheme.gold),
                    const SizedBox(width: 9),
                    const Expanded(
                      child: Text(
                        'Hatim ilerlemesi',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '%$percentage',
                      style: const TextStyle(
                        color: AppTheme.gold,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 10,
                    value: summary.progress,
                    color: AppTheme.gold,
                    backgroundColor: Colors.white.withValues(alpha: .16),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${summary.completedJuz.length}/30 cüz • Bitiş ${_formatDate(summary.plan.targetDate)}',
                  style: const TextStyle(color: Color(0xFFD0E4FF)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PlanStat(
                  value: summary.isOverdue
                      ? '${summary.overdueDays}'
                      : '${summary.remainingDays}',
                  label: summary.isOverdue ? 'Geciken gün' : 'Kalan gün',
                  icon: Icons.calendar_today_outlined,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _PlanStat(
                  value: '${summary.currentStreak}',
                  label: 'Okuma serisi',
                  icon: Icons.local_fire_department_outlined,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _PlanStat(
                  value: '${summary.remainingJuz}',
                  label: 'Kalan cüz',
                  icon: Icons.menu_book_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _TodayReadingCard(summary: summary),
          if (widget.allowOpenJuzList) ...[
            const SizedBox(height: 13),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.auto_stories_rounded),
              label: const Text('Cüzleri aç ve okumaya başla'),
            ),
          ],
          const SizedBox(height: 18),
          _ReadingWeek(days: summary.week),
          const SizedBox(height: 14),
          _InfoStrip(
            icon: summary.isOnTrack
                ? Icons.trending_up_rounded
                : Icons.update_rounded,
            title: summary.isComplete
                ? 'Hatmini tamamladın!'
                : summary.isOnTrack
                    ? 'Planına uygun ilerliyorsun'
                    : 'Bugünkü hedef güncellendi',
            subtitle: summary.isComplete
                ? 'Dilersen yeni bir hatim planı oluşturabilirsin.'
                : 'Kalan süreye göre günlük hedefin otomatik hesaplanır.',
          ),
        ],
      ),
    );
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

class _TodayReadingCard extends StatelessWidget {
  const _TodayReadingCard({required this.summary});

  final QuranReadingPlanSummary summary;

  @override
  Widget build(BuildContext context) {
    final recommended = summary.recommendedJuz;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        boxShadow: AppTheme.ambientShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppTheme.mint,
                foregroundColor: AppTheme.emerald,
                child: Icon(Icons.today_rounded),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bugünün hedefi',
                      style: TextStyle(
                        color: AppTheme.navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      summary.isComplete
                          ? 'Plan tamamlandı'
                          : '${summary.todayTarget} cüz • Bugün ${summary.completedToday} tamamlandı',
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (recommended.isNotEmpty) ...[
            const SizedBox(height: 15),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: recommended
                  .map(
                    (number) => Chip(
                      avatar: const Icon(Icons.menu_book_rounded, size: 17),
                      label: Text('$number. Cüz'),
                      backgroundColor: AppTheme.mint.withValues(alpha: .45),
                      side: BorderSide.none,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanStat extends StatelessWidget {
  const _PlanStat({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.ambientShadow,
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.gold, size: 19),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.navy,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _ReadingWeek extends StatelessWidget {
  const _ReadingWeek({required this.days});

  final List<QuranReadingDay> days;
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
            'Bu haftaki okumalar',
            style: TextStyle(
              color: AppTheme.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 13),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(days.length, (index) {
              final day = days[index];
              return Column(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: day.hasReading
                          ? AppTheme.emerald
                          : AppTheme.surfaceLow,
                    ),
                    child: day.hasReading
                        ? Text(
                            '${day.completedJuz}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        : const Icon(Icons.remove,
                            color: AppTheme.outline, size: 15),
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

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: AppTheme.ambientShadow,
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.emerald),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style:
                      const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  const months = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
