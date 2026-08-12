import 'package:flutter/material.dart';

import '../models/religious_day.dart';
import '../services/firebase_service.dart' show FirebaseService;
import '../services/religious_days_service.dart';
import '../services/ad_service.dart';
import '../services/app_review_service.dart';
import '../theme/app_theme.dart';
import 'dhikr_counter_screen.dart';
import 'esmaul_husna_screen.dart';

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

  Future<void> _openStoreReview() async {
    try {
      await AppReviewService().openStoreListing();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mağaza sayfası şu anda açılamadı.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final days =
        _showPast ? _service.getPassedDays() : _service.getUpcomingDays();
    final featured = days.isEmpty ? null : days.first;

    return Scaffold(
      backgroundColor: AppTheme.ivory,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 72,
        titleSpacing: 20,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _showPast ? 'Geçmiş Dini Günler' : 'Dini Günler',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _showPast
                  ? 'Geride kalan özel günler'
                  : 'Manevi günleri ve tarihleri takip et',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Uygulamayı değerlendir',
            icon: const Icon(Icons.star_outline_rounded, size: 28),
            onPressed: _openStoreReview,
          ),
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
                      if (!_showPast) ...[
                        const _SectionHeader(
                          eyebrow: 'DİNİ TAKVİM',
                          title: 'Sıradaki dini gün',
                          subtitle: 'Yaklaşan özel günü bir bakışta gör',
                        ),
                        const SizedBox(height: 12),
                        if (featured != null) _FeaturedDay(day: featured),
                        const SizedBox(height: 26),
                        const _SectionHeader(
                          eyebrow: 'KEŞFET',
                          title: 'Manevi araçlar',
                          subtitle: 'Günlük ibadet ve ezber takibini sürdür',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _SpiritualToolCard(
                                icon: Icons.touch_app_rounded,
                                title: 'Zikirmatik',
                                subtitle: 'Hedefini tamamla, serini koru',
                                background: AppTheme.emerald,
                                foreground: Colors.white,
                                iconBackground: AppTheme.mint,
                                iconColor: AppTheme.emerald,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => const DhikrCounterScreen(),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SpiritualToolCard(
                                icon: Icons.auto_awesome_rounded,
                                title: 'Esmaül Hüsna',
                                subtitle: '99 ismi dinle ve ezberle',
                                background: AppTheme.navy,
                                foreground: Colors.white,
                                iconBackground: AppTheme.mint,
                                iconColor: AppTheme.emerald,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => const EsmaulHusnaScreen(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 26),
                        _SectionHeader(
                          eyebrow: 'TAKVİM',
                          title: 'Yaklaşan dini günler',
                          subtitle:
                              '${days.length - 1} önemli tarih seni bekliyor',
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        _SectionHeader(
                          eyebrow: 'ARŞİV',
                          title: 'Geçmiş dini günler',
                          subtitle: '${days.length} tarih listeleniyor',
                        ),
                        const SizedBox(height: 12),
                      ],
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 46,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: AppTheme.gold,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: const TextStyle(
                  color: AppTheme.emerald,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.navy,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SpiritualToolCard extends StatelessWidget {
  const _SpiritualToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.background,
    required this.foreground,
    required this.iconBackground,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color background;
  final Color foreground;
  final Color iconBackground;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          height: 142,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: iconBackground,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: iconColor, size: 21),
                    ),
                    const Icon(
                      Icons.arrow_outward_rounded,
                      color: AppTheme.gold,
                      size: 20,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground.withValues(alpha: .74),
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
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
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.navy, Color(0xFF064D5A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppTheme.gold.withValues(alpha: .32),
                      ),
                    ),
                    child: const Text(
                      'SIRADAKİ DİNİ GÜN',
                      style: TextStyle(
                        color: AppTheme.gold,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .9,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      day.countdownText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 21),
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: .14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _iconFor(day.iconType),
                      color: AppTheme.gold,
                      size: 31,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          day.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _fullDate(day.date),
                          style: const TextStyle(
                            color: Color(0xFFD6E7EA),
                            fontSize: 13,
                          ),
                        ),
                        if (day.hijriDay != null && day.hijriMonth != null)
                          Text(
                            '${day.hijriDay} ${day.hijriMonth}',
                            style: const TextStyle(
                              color: AppTheme.gold,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
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
