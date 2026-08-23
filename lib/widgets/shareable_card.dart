import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/daily_item.dart';

/// Ana sayfadaki dua, hadis ve ayetler için sosyal medya paylaşım kartı.
/// Tasarım seçilen gönderi, hikâye ve kare ölçülerine kendini uyarlar.
class ShareableCard extends StatelessWidget {
  const ShareableCard({
    super.key,
    required this.item,
    this.width = 1080,
    this.height = 1080,
  });

  final DailyItem item;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = _CardPalette.forType(item.type);
    final isStory = height / width > 1.5;
    final outerPadding = isStory ? 72.0 : 58.0;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [palette.top, palette.middle, palette.bottom],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0, .52, 1],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _IslamicPatternPainter(accent: palette.accent),
              ),
            ),
            Positioned(
              top: -width * .35,
              right: -width * .32,
              child: _GlowOrb(
                size: width * .86,
                color: palette.accent.withValues(alpha: .13),
              ),
            ),
            Positioned(
              bottom: -width * .42,
              left: -width * .34,
              child: _GlowOrb(
                size: width * .92,
                color: Colors.white.withValues(alpha: .055),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(outerPadding),
              child: Column(
                children: [
                  _BrandHeader(accent: palette.accent),
                  SizedBox(height: isStory ? 70 : 42),
                  Expanded(
                    child: _ContentPanel(
                      item: item,
                      palette: palette,
                      width: width,
                      isStory: isStory,
                    ),
                  ),
                  SizedBox(height: isStory ? 56 : 34),
                  _Footer(accent: palette.accent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentPanel extends StatelessWidget {
  const _ContentPanel({
    required this.item,
    required this.palette,
    required this.width,
    required this.isStory,
  });

  final DailyItem item;
  final _CardPalette palette;
  final double width;
  final bool isStory;

  @override
  Widget build(BuildContext context) {
    final fontSize = switch (item.text.characters.length) {
      <= 95 => isStory ? 55.0 : 50.0,
      <= 180 => isStory ? 49.0 : 44.0,
      <= 300 => isStory ? 43.0 : 39.0,
      _ => isStory ? 37.0 : 34.0,
    };

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isStory ? 72 : 62,
        isStory ? 76 : 58,
        isStory ? 72 : 62,
        isStory ? 64 : 52,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: .13),
            Colors.white.withValues(alpha: .065),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(44),
        border: Border.all(
          color: palette.accent.withValues(alpha: .48),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .20),
            blurRadius: 42,
            offset: const Offset(0, 22),
          ),
          BoxShadow(
            color: palette.accent.withValues(alpha: .08),
            blurRadius: 65,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          _TypeBadge(
            icon: palette.icon,
            label: item.getTitle(),
            accent: palette.accent,
          ),
          SizedBox(height: isStory ? 56 : 38),
          Text(
            '“',
            style: TextStyle(
              color: palette.accent,
              fontSize: isStory ? 112 : 92,
              height: .65,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: isStory ? 34 : 24),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: width - (isStory ? 270 : 240),
                  child: Text(
                    item.text.trim(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.text,
                      fontSize: fontSize,
                      height: 1.55,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .15,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: .14),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: isStory ? 50 : 34),
          _SourceLabel(source: item.source, accent: palette.accent),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: .25),
                blurRadius: 22,
              ),
            ],
          ),
          child: const Icon(
            Icons.nightlight_round,
            color: Color(0xFF082C34),
            size: 30,
          ),
        ),
        const SizedBox(width: 18),
        const Text(
          'HER GÜN İSLAM',
          style: TextStyle(
            color: Colors.white,
            fontSize: 27,
            fontWeight: FontWeight.w800,
            letterSpacing: 4.2,
          ),
        ),
      ],
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({
    required this.icon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 15),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: accent.withValues(alpha: .48)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 28),
          const SizedBox(width: 13),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: accent,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceLabel extends StatelessWidget {
  const _SourceLabel({required this.source, required this.accent});

  final String source;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (source.trim().isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 54, height: 1.5, color: accent.withValues(alpha: .7)),
        const SizedBox(width: 19),
        Flexible(
          child: Text(
            source.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: accent,
              fontSize: 25,
              height: 1.25,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              letterSpacing: .5,
            ),
          ),
        ),
        const SizedBox(width: 19),
        Container(width: 54, height: 1.5, color: accent.withValues(alpha: .7)),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Diamond(color: accent.withValues(alpha: .75), size: 9),
        const SizedBox(width: 18),
        Text(
          'OKU  •  DÜŞÜN  •  PAYLAŞ',
          style: TextStyle(
            color: Colors.white.withValues(alpha: .70),
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 3.2,
          ),
        ),
        const SizedBox(width: 18),
        _Diamond(color: accent.withValues(alpha: .75), size: 9),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

class _Diamond extends StatelessWidget {
  const _Diamond({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(width: size, height: size, color: color),
    );
  }
}

class _IslamicPatternPainter extends CustomPainter {
  const _IslamicPatternPainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accent.withValues(alpha: .07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const spacing = 132.0;
    const motifSize = 25.0;

    for (var y = -spacing; y < size.height + spacing; y += spacing) {
      final row = (y / spacing).round();
      final offset = row.isEven ? 0.0 : spacing / 2;
      for (var x = -spacing; x < size.width + spacing; x += spacing) {
        final center = Offset(x + offset, y);
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(math.pi / 4);
        canvas.drawRect(
          const Rect.fromLTWH(
            -motifSize,
            -motifSize,
            motifSize * 2,
            motifSize * 2,
          ),
          paint,
        );
        canvas.rotate(math.pi / 4);
        canvas.drawRect(
          const Rect.fromLTWH(
            -motifSize,
            -motifSize,
            motifSize * 2,
            motifSize * 2,
          ),
          paint,
        );
        canvas.restore();
      }
    }

    final archPaint = Paint()
      ..color = accent.withValues(alpha: .10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final archWidth = size.width * .72;
    final archRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * .53),
      width: archWidth,
      height: size.height * .72,
    );
    canvas.drawArc(archRect, math.pi, math.pi, false, archPaint);
  }

  @override
  bool shouldRepaint(covariant _IslamicPatternPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

class _CardPalette {
  const _CardPalette({
    required this.top,
    required this.middle,
    required this.bottom,
    required this.accent,
    required this.text,
    required this.icon,
  });

  final Color top;
  final Color middle;
  final Color bottom;
  final Color accent;
  final Color text;
  final IconData icon;

  factory _CardPalette.forType(String type) {
    return switch (type.toLowerCase()) {
      'ayah' => const _CardPalette(
          top: Color(0xFF062F2A),
          middle: Color(0xFF0A493E),
          bottom: Color(0xFF082D35),
          accent: Color(0xFFE0B95E),
          text: Color(0xFFFFFCF2),
          icon: Icons.auto_stories_rounded,
        ),
      'dua' => const _CardPalette(
          top: Color(0xFF30213D),
          middle: Color(0xFF523450),
          bottom: Color(0xFF172D3A),
          accent: Color(0xFFF0C978),
          text: Color(0xFFFFFAF2),
          icon: Icons.volunteer_activism_rounded,
        ),
      'hadith' => const _CardPalette(
          top: Color(0xFF032A3D),
          middle: Color(0xFF0A4250),
          bottom: Color(0xFF092D38),
          accent: Color(0xFFDDB65C),
          text: Color(0xFFFFFCF5),
          icon: Icons.menu_book_rounded,
        ),
      _ => const _CardPalette(
          top: Color(0xFF0B2940),
          middle: Color(0xFF174A50),
          bottom: Color(0xFF102938),
          accent: Color(0xFFDDB65C),
          text: Colors.white,
          icon: Icons.wb_twilight_rounded,
        ),
    };
  }
}
