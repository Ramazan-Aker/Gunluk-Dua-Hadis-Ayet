import 'package:flutter/material.dart';

/// Shimmer-style loading list for surah detail (no extra packages).
class SurahDetailShimmerList extends StatefulWidget {
  final int itemCount;

  const SurahDetailShimmerList({
    super.key,
    this.itemCount = 6,
  });

  @override
  State<SurahDetailShimmerList> createState() => _SurahDetailShimmerListState();
}

class _SurahDetailShimmerListState extends State<SurahDetailShimmerList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: List.generate(
          widget.itemCount,
          (i) => _ShimmerCard(animation: _controller),
        ),
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  final Animation<double> animation;

  const _ShimmerCard({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: _bone(width: 120, height: 22),
                        ),
                        const SizedBox(height: 12),
                        _bone(width: double.infinity, height: 18),
                        const SizedBox(height: 8),
                        _bone(width: double.infinity, height: 18),
                        const SizedBox(height: 8),
                        _bone(width: 200, height: 18),
                        const SizedBox(height: 14),
                        _bone(width: double.infinity, height: 14),
                        const SizedBox(height: 6),
                        _bone(width: 260, height: 14),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _bone(width: 28, height: 28),
                            const SizedBox(width: 20),
                            _bone(width: 28, height: 28),
                            const SizedBox(width: 20),
                            _bone(width: 28, height: 28),
                            const SizedBox(width: 20),
                            _bone(width: 28, height: 28),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ShimmerSweepPainter(progress: t),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _bone({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE8E8E8),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

class _ShimmerSweepPainter extends CustomPainter {
  final double progress;

  _ShimmerSweepPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * 0.45;
    final left = -w + (size.width + w * 2) * progress;
    final rect = Rect.fromLTWH(left, 0, w, size.height);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.5, 1.0],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _ShimmerSweepPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
