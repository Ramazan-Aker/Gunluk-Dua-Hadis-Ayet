import 'package:flutter/material.dart';
import '../models/daily_item.dart';
import '../theme/app_theme.dart';

/// Beautiful card widget to display Daily Dua/Hadith/Ayah
class ItemCard extends StatefulWidget {
  final DailyItem item;
  final VoidCallback onShare;
  final VoidCallback onNext;
  final VoidCallback? onMarkAsRead;
  final bool isSharing;
  final bool isRead;

  /// iOS share sheet konumu için paylaş butonuna atanan key
  final GlobalKey? shareButtonKey;

  const ItemCard({
    super.key,
    required this.item,
    required this.onShare,
    required this.onNext,
    this.onMarkAsRead,
    this.isSharing = false,
    this.isRead = false,
    this.shareButtonKey,
  });

  @override
  State<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navyContainer.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: Colors.white,
                child: CustomPaint(painter: _DiamondPatternPainter()),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title with icon
                  Row(
                    children: [
                      Text(
                        widget.item.getIcon(),
                        style: const TextStyle(fontSize: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.item.getTitle(),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.navy,
                          ),
                        ),
                      ),
                      if (widget.isRead) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.check_circle,
                          color: AppTheme.emerald,
                          size: 24,
                        ),
                      ] else if (widget.onMarkAsRead != null) ...[
                        IconButton(
                          tooltip: 'Okundu olarak işaretle',
                          onPressed: widget.onMarkAsRead,
                          icon: const Icon(Icons.bookmark_border_rounded,
                              color: AppTheme.navy),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Divider
                  Container(
                    height: 2,
                    width: 60,
                    margin: const EdgeInsets.symmetric(horizontal: 100),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.navy.withValues(alpha: 0.12),
                          AppTheme.navy,
                          AppTheme.navy.withValues(alpha: 0.12),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Main text
                  Text(
                    widget.item.text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.8,
                      color: AppTheme.text,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Source
                  Text(
                    '— ${widget.item.source}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      // Share button
                      Expanded(
                        child: ElevatedButton.icon(
                          key: widget.shareButtonKey,
                          onPressed: widget.isSharing ? null : widget.onShare,
                          icon: widget.isSharing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Icon(Icons.share, size: 20),
                          label: Text(
                              widget.isSharing ? 'Oluşturuluyor...' : 'Paylaş'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.surfaceLow,
                            foregroundColor: AppTheme.navy,
                            disabledBackgroundColor: AppTheme.surfaceLow,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Next button (amber accent)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: widget.onNext,
                          icon: const Icon(Icons.refresh, size: 20),
                          label: const Text('Sonraki'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.navy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: const StadiumBorder(),
                            elevation: 0,
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
    );
  }
}

class _DiamondPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppTheme.navy.withValues(alpha: .025);
    const cell = 44.0;
    for (double y = -cell; y < size.height + cell; y += cell) {
      for (double x = -cell; x < size.width + cell; x += cell) {
        final path = Path()
          ..moveTo(x + cell / 2, y)
          ..lineTo(x + cell, y + cell / 2)
          ..lineTo(x + cell / 2, y + cell)
          ..lineTo(x, y + cell / 2)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Loading widget
class LoadingCard extends StatelessWidget {
  const LoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: Color(0xFF1E40AF),
          ),
          SizedBox(height: 20),
          Text(
            'Yükleniyor...',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF1E40AF),
            ),
          ),
        ],
      ),
    );
  }
}
