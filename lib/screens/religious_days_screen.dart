import 'package:flutter/material.dart';

import '../models/religious_day.dart';
import '../services/firebase_service.dart' show FirebaseService;
import '../services/religious_days_service.dart';
import '../services/ad_service.dart';
import '../theme/app_theme.dart';

class ReligiousDaysScreen extends StatefulWidget {
  const ReligiousDaysScreen({super.key});

  @override
  State<ReligiousDaysScreen> createState() => _ReligiousDaysScreenState();
}

class _ReligiousDaysScreenState extends State<ReligiousDaysScreen> {
  final _service = ReligiousDaysService();
  bool _showPast = false;

  @override
  void initState() {
    super.initState();
    FirebaseService.logScreenView(screenName: 'screen_religious_days');
  }

  @override
  Widget build(BuildContext context) {
    final days =
        _showPast ? _service.getPassedDays() : _service.getUpcomingDays();
    final featured = days.isEmpty ? null : days.first;

    return Scaffold(
      backgroundColor: AppTheme.ivory,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 30),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(_showPast ? 'Geçmiş Dini Günler' : 'Dini Günler'),
        actions: [
          IconButton(
            tooltip: _showPast ? 'Yaklaşan günler' : 'Geçmiş günler',
            icon: Icon(
                _showPast ? Icons.upcoming_outlined : Icons.history_rounded,
                size: 30),
            onPressed: () => setState(() => _showPast = !_showPast),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: days.isEmpty
                ? const Center(child: Text('Gösterilecek dini gün bulunamadı.'))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    children: [
                      if (!_showPast && featured != null)
                        _FeaturedDay(day: featured),
                      if (!_showPast) const SizedBox(height: 20),
                      ...days.skip(_showPast ? 0 : 1).map(
                            (day) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _DayTile(day: day),
                            ),
                          ),
                    ],
                  ),
          ),
          const AdBannerWidget(),
        ],
      ),
    );
  }
}

class _FeaturedDay extends StatelessWidget {
  final ReligiousDay day;
  const _FeaturedDay({required this.day});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: BoxDecoration(
        color: AppTheme.navy,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: .18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _CheckerPainter()),
          ),
          Column(
            children: [
              Icon(_iconFor(day.iconType),
                  color: const Color(0xFFFFC95C), size: 46),
              const SizedBox(height: 14),
              Text(
                day.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                _fullDate(day.date),
                style: const TextStyle(color: Color(0xFFD6DCE3), fontSize: 16),
              ),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  day.countdownText,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  final ReligiousDay day;
  const _DayTile({required this.day});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.ambientShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.mint,
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                Icon(_iconFor(day.iconType), color: AppTheme.emerald, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(day.name,
                    style: const TextStyle(
                        color: AppTheme.navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(_fullDate(day.date),
                    style: const TextStyle(color: AppTheme.text, fontSize: 14)),
                if (day.hijriDay != null && day.hijriMonth != null)
                  Text('${day.hijriDay} ${day.hijriMonth}',
                      style: const TextStyle(
                          color: Color(0xFF777980), fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            constraints: const BoxConstraints(maxWidth: 92),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: day.daysFromNow >= 0
                  ? const Color(0xFFFFDEA3).withValues(alpha: .55)
                  : AppTheme.surfaceLow,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              day.countdownText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: day.daysFromNow >= 0
                    ? const Color(0xFF8A6308)
                    : AppTheme.textMuted,
                fontSize: 12,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconFor(IconType type) => switch (type) {
      IconType.moon => Icons.nightlight_round,
      IconType.mosque => Icons.mosque_rounded,
      IconType.star => Icons.water_drop_outlined,
      IconType.calendar => Icons.calendar_month_outlined,
    };

String _fullDate(DateTime date) {
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
    'Aralık'
  ];
  const weekdays = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar'
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year} ${weekdays[date.weekday - 1]}';
}

class _CheckerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    const cell = 18.0;
    for (double y = 0; y < size.height; y += cell) {
      for (double x = 0; x < size.width; x += cell) {
        final even = ((x / cell).floor() + (y / cell).floor()).isEven;
        paint.color = Colors.white.withValues(alpha: even ? .06 : .015);
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
