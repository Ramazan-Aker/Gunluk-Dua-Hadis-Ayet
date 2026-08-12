import 'package:flutter/material.dart';

import '../models/prayer_tracking.dart';
import '../theme/app_theme.dart';

class PrayerTrackingCard extends StatelessWidget {
  const PrayerTrackingCard({
    super.key,
    required this.summary,
    required this.onPrayerToggled,
    required this.onGoalChanged,
    required this.onPauseChanged,
    this.isBusy = false,
  });

  final PrayerTrackingSummary summary;
  final ValueChanged<TrackedPrayer> onPrayerToggled;
  final ValueChanged<int> onGoalChanged;
  final ValueChanged<bool> onPauseChanged;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final today = summary.today;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.ambientShadow,
        border: Border.all(color: AppTheme.navy.withValues(alpha: .07)),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: today.isPaused ? _buildPaused(context) : _buildActive(context),
      ),
    );
  }

  Widget _buildActive(BuildContext context) {
    final today = summary.today;
    final completed = today.completedCount;
    return Column(
      key: const ValueKey('active-prayer-tracking'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: AppTheme.mint,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded,
                  color: AppTheme.emerald),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Namaz Takibi',
                      style: TextStyle(
                          color: AppTheme.navy,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text('Bugünkü ilerlemeni kendin için kaydet',
                      style:
                          TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                ],
              ),
            ),
            _buildStreakBadge(),
            PopupMenuButton<String>(
              enabled: !isBusy,
              tooltip: 'Takip seçenekleri',
              icon: const Icon(Icons.more_vert_rounded,
                  color: AppTheme.textMuted),
              onSelected: (value) {
                if (value == 'pause') onPauseChanged(true);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'pause',
                  child: Row(
                    children: [
                      Icon(Icons.pause_circle_outline_rounded),
                      SizedBox(width: 10),
                      Text('Bugün takibi duraklat'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: today.progress,
                  minHeight: 9,
                  backgroundColor: AppTheme.surfaceLow,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppTheme.emerald),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text('$completed/${today.goal}',
                style: const TextStyle(
                    color: AppTheme.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
          ],
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: Text(
                _motivationText(today),
                style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ),
            PopupMenuButton<int>(
              enabled: !isBusy,
              tooltip: 'Günlük hedefi değiştir',
              onSelected: onGoalChanged,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 1, child: Text('Günde 1 vakit')),
                PopupMenuItem(value: 3, child: Text('Günde 3 vakit')),
                PopupMenuItem(value: 5, child: Text('Günde 5 vakit')),
              ],
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.flag_outlined,
                        color: Color(0xFF6B4C00), size: 15),
                    const SizedBox(width: 5),
                    Text('Hedef ${today.goal}',
                        style: const TextStyle(
                            color: Color(0xFF6B4C00),
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = (constraints.maxWidth - 16) / 3;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TrackedPrayer.values.map((prayer) {
                final selected = today.completed.contains(prayer);
                return SizedBox(
                  width: itemWidth,
                  child: Semantics(
                    button: true,
                    checked: selected,
                    label: '${prayer.label} namazı',
                    child: Material(
                      color: selected ? AppTheme.mint : AppTheme.surfaceLow,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: isBusy ? null : () => onPrayerToggled(prayer),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                selected
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                size: 18,
                                color: selected
                                    ? AppTheme.emerald
                                    : AppTheme.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(prayer.label,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: selected
                                            ? AppTheme.emerald
                                            : AppTheme.text,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 13),
        _buildWeek(),
      ],
    );
  }

  Widget _buildPaused(BuildContext context) {
    return Row(
      key: const ValueKey('paused-prayer-tracking'),
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: AppTheme.surfaceLow,
            shape: BoxShape.circle,
          ),
          child:
              const Icon(Icons.self_improvement_rounded, color: AppTheme.navy),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Takip bugün duraklatıldı',
                  style: TextStyle(
                      color: AppTheme.navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              SizedBox(height: 3),
              Text('Serin korunuyor. Hazır olduğunda devam edebilirsin.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            ],
          ),
        ),
        TextButton(
          onPressed: isBusy ? null : () => onPauseChanged(false),
          child: const Text('Devam et'),
        ),
      ],
    );
  }

  Widget _buildStreakBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department_rounded,
              color: AppTheme.gold, size: 17),
          const SizedBox(width: 3),
          Text('${summary.currentStreak}',
              style: const TextStyle(
                  color: Color(0xFF6B4C00),
                  fontWeight: FontWeight.w800,
                  fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildWeek() {
    const labels = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(summary.week.length, (index) {
        final day = summary.week[index];
        final isToday = _sameDay(day.date, summary.today.date);
        final color = day.isPaused
            ? AppTheme.outline
            : day.goalMet
                ? AppTheme.emerald
                : AppTheme.surfaceLow;
        return Semantics(
          label:
              '${labels[index]}: ${day.isPaused ? 'duraklatıldı' : '${day.completedCount}/${day.goal}'}',
          child: Column(
            children: [
              Text(labels[index],
                  style: TextStyle(
                      color: isToday ? AppTheme.navy : AppTheme.textMuted,
                      fontSize: 10,
                      fontWeight: isToday ? FontWeight.w800 : FontWeight.w500)),
              const SizedBox(height: 6),
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isToday
                      ? Border.all(color: AppTheme.gold, width: 2)
                      : null,
                ),
                child: day.isPaused
                    ? const Icon(Icons.pause_rounded,
                        size: 14, color: Colors.white)
                    : day.goalMet
                        ? const Icon(Icons.check_rounded,
                            size: 16, color: Colors.white)
                        : Text('${day.completedCount}',
                            style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      }),
    );
  }

  String _motivationText(PrayerTrackingDay day) {
    if (day.goalMet) return 'Bugünkü hedefine ulaştın. İstikrarın kıymetli.';
    if (day.completedCount == 0) {
      return 'Her adım kıymetli. Hazır olduğunda başlayabilirsin.';
    }
    final remaining = day.goal - day.completedCount;
    return 'Hedefine $remaining vakit kaldı.';
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
