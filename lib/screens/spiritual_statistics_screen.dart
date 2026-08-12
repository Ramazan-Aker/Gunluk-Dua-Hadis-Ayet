import 'package:flutter/material.dart';

import '../models/spiritual_statistics.dart';
import '../services/spiritual_statistics_service.dart';
import '../theme/app_theme.dart';

class SpiritualStatisticsScreen extends StatefulWidget {
  final SpiritualStatisticsService? service;

  const SpiritualStatisticsScreen({super.key, this.service});

  @override
  State<SpiritualStatisticsScreen> createState() =>
      _SpiritualStatisticsScreenState();
}

class _SpiritualStatisticsScreenState extends State<SpiritualStatisticsScreen> {
  late final SpiritualStatisticsService _service =
      widget.service ?? SpiritualStatisticsService();
  StatisticsPeriod _period = StatisticsPeriod.week;
  SpiritualStatisticsSummary? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final summary = await _service.load(period: _period);
    if (mounted) {
      setState(() {
        _summary = summary;
        _loading = false;
      });
    }
  }

  Future<void> _changePeriod(StatisticsPeriod period) async {
    if (period == _period) return;
    setState(() => _period = period);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ivory,
      appBar: AppBar(title: const Text('Manevi İstatistikler')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 34),
          children: [
            Center(
              child: SegmentedButton<StatisticsPeriod>(
                segments: [
                  for (final period in StatisticsPeriod.values)
                    ButtonSegment(value: period, label: Text(period.label)),
                ],
                selected: {_period},
                onSelectionChanged: (value) => _changePeriod(value.first),
              ),
            ),
            const SizedBox(height: 14),
            if (_loading)
              const SizedBox(
                  height: 320,
                  child: Center(child: CircularProgressIndicator()))
            else
              _buildContent(_summary!),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(SpiritualStatisticsSummary summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OverviewCard(summary: summary),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                    width: width,
                    child: _MetricTile(
                        icon: Icons.mosque_rounded,
                        label: 'Namaz',
                        value: '${summary.totalPrayers}',
                        color: AppTheme.emerald)),
                SizedBox(
                    width: width,
                    child: _MetricTile(
                        icon: Icons.touch_app_rounded,
                        label: 'Zikir',
                        value: '${summary.totalDhikr}',
                        color: AppTheme.navy)),
                SizedBox(
                    width: width,
                    child: _MetricTile(
                        icon: Icons.auto_stories_rounded,
                        label: 'Tamamlanan cüz',
                        value: '${summary.totalCompletedJuz}',
                        color: AppTheme.gold)),
                SizedBox(
                    width: width,
                    child: _MetricTile(
                        icon: Icons.checklist_rounded,
                        label: 'Plan günü',
                        value: '${summary.completedPlanDays}',
                        color: const Color(0xFF7A4DB3))),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _MetricChart(
          title: 'Namaz',
          subtitle: '${summary.totalPrayers} vakit tamamlandı',
          icon: Icons.mosque_rounded,
          color: AppTheme.emerald,
          values: summary.days.map((day) => day.prayers.toDouble()).toList(),
          days: summary.days,
        ),
        const SizedBox(height: 12),
        _MetricChart(
          title: 'Zikir',
          subtitle: '${summary.totalDhikr} toplam zikir',
          icon: Icons.touch_app_rounded,
          color: AppTheme.navy,
          values: summary.days.map((day) => day.dhikr.toDouble()).toList(),
          days: summary.days,
        ),
        const SizedBox(height: 12),
        _MetricChart(
          title: 'Kur’an',
          subtitle: '${summary.totalCompletedJuz} cüz tamamlandı',
          icon: Icons.auto_stories_rounded,
          color: const Color(0xFFD79A22),
          values:
              summary.days.map((day) => day.completedJuz.toDouble()).toList(),
          days: summary.days,
        ),
        const SizedBox(height: 12),
        _MetricChart(
          title: 'Günlük Plan',
          subtitle: '${summary.completedPlanDays} gün tüm hedefler tamamlandı',
          icon: Icons.checklist_rounded,
          color: const Color(0xFF7A4DB3),
          values: summary.days
              .map((day) => day.dailyPlanCompleted ? 1.0 : 0.0)
              .toList(),
          days: summary.days,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppTheme.mint, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              const CircleAvatar(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.emerald,
                  child: Icon(Icons.history_toggle_off_rounded)),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(
                      'Bu dönemde ${summary.totalKazaPerformed} kaza namazı tamamlandı.',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: AppTheme.navy))),
            ],
          ),
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final SpiritualStatisticsSummary summary;
  const _OverviewCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final prayerPercent = (summary.prayerCompletionRatio * 100).round();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppTheme.navy, AppTheme.navyContainer]),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              summary.period == StatisticsPeriod.week
                  ? 'Son 7 günün özeti'
                  : 'Son 30 günün özeti',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child: _HeaderValue(
                      value: '${summary.activeDays}', label: 'aktif gün')),
              Container(width: 1, height: 42, color: Colors.white24),
              Expanded(
                  child: _HeaderValue(
                      value: '%$prayerPercent', label: 'namaz oranı')),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderValue extends StatelessWidget {
  final String value;
  final String label;
  const _HeaderValue({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: AppTheme.gold,
                  fontSize: 26,
                  fontWeight: FontWeight.w900)),
          Text(label,
              style: const TextStyle(color: Color(0xFFD8F5EC), fontSize: 12)),
        ],
      );
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _MetricTile(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.outline.withValues(alpha: .2))),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 9),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(value,
                      style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.navy)),
                  Text(label,
                      maxLines: 2,
                      style: const TextStyle(
                          fontSize: 11.5, color: AppTheme.outline)),
                ])),
          ],
        ),
      );
}

class _MetricChart extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<double> values;
  final List<SpiritualStatisticsDay> days;

  const _MetricChart(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.color,
      required this.values,
      required this.days});

  @override
  Widget build(BuildContext context) {
    final maxValue =
        values.fold<double>(1, (max, value) => value > max ? value : max);
    final weekly = days.length == 7;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.outline.withValues(alpha: .2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: .12),
                foregroundColor: color,
                child: Icon(icon, size: 20)),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, color: AppTheme.navy)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.outline)),
                ])),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            height: 112,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var index = 0; index < values.length; index++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: weekly ? 3 : 1),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (weekly && values[index] > 0)
                            Text('${values[index].round()}',
                                style: const TextStyle(
                                    fontSize: 9, color: AppTheme.outline)),
                          const SizedBox(height: 2),
                          Container(
                            height: values[index] == 0
                                ? 3
                                : 78 * (values[index] / maxValue),
                            decoration: BoxDecoration(
                                color: values[index] == 0
                                    ? AppTheme.surfaceLow
                                    : color,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(5))),
                          ),
                          const SizedBox(height: 4),
                          if (weekly)
                            Text(_weekday(days[index].date.weekday),
                                style: const TextStyle(
                                    fontSize: 9, color: AppTheme.outline)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!weekly)
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${days.first.date.day}.${days.first.date.month}',
                  style:
                      const TextStyle(fontSize: 10, color: AppTheme.outline)),
              Text('${days.last.date.day}.${days.last.date.month}',
                  style:
                      const TextStyle(fontSize: 10, color: AppTheme.outline)),
            ]),
        ],
      ),
    );
  }

  String _weekday(int weekday) =>
      const ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'][weekday - 1];
}
