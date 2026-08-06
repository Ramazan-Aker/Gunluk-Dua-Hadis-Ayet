import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/greeting_message.dart';

/// Shareable card for Cuma, Kandil, and Bayram messages
/// Renders at the selected social-media dimensions; use FittedBox for preview.
class GreetingShareableCard extends StatelessWidget {
  final String categoryId;
  final String messageText;
  final String messageTitle;
  final String signature;

  /// Arka plan görseli (Pixabay vb.)
  final String? imageUrl;
  final double width;
  final double height;

  const GreetingShareableCard({
    super.key,
    required this.categoryId,
    required this.messageText,
    required this.messageTitle,
    this.signature = '',
    this.imageUrl,
    this.width = 1080,
    this.height = 1080,
  });

  GreetingCategory get _categoryType =>
      GreetingCategoryInfo.getCategoryType(categoryId);

  bool get _hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    switch (_categoryType) {
      case GreetingCategory.cuma:
        return _buildCumaCard();
      case GreetingCategory.kandil:
        return _buildKandilCard();
      case GreetingCategory.bayram:
        return _buildBayramCard();
    }
  }

  Widget _buildMessageContent(double fontSize, Color textColor,
      {bool hasImage = false}) {
    return SizedBox(
      width: width - 120,
      height: height * .46,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: SizedBox(
          width: width - 160,
          child: Text(
            '"$messageText"',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              height: 2.0,
              color: hasImage ? Colors.white : textColor,
              fontWeight: FontWeight.w600,
              shadows: hasImage
                  ? [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageBackground() {
    if (imageUrl == null || imageUrl!.isEmpty) return const SizedBox.shrink();
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          fit: BoxFit.cover,
          fadeInDuration: const Duration(milliseconds: 300),
          placeholder: (_, __) => Container(
            color: const Color(0xFFDBEAFE),
          ),
          errorWidget: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  /// Görsel üzerinde alttan üste siyah gradyan - metin her zaman okunabilir
  /// Altta siyah, üstte şeffaf - beyaz metin her zaman okunur
  Widget _buildImageOverlay() {
    if (imageUrl == null || imageUrl!.isEmpty) return const SizedBox.shrink();
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.4),
              Colors.black.withValues(alpha: 0.85),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
    );
  }

  /// Görsel varken metin için sadece padding - arka plan gradyan üzerinde
  Widget _buildTextContainer(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
      child: child,
    );
  }

  Widget _imageBrandBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .38),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: .24)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mosque_rounded, size: 22, color: Colors.white),
          SizedBox(width: 9),
          Text(
            'Her Gün İslam',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageAttribution() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 42, height: 1, color: Colors.white54),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              messageTitle.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 17,
                letterSpacing: 1.7,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Container(width: 42, height: 1, color: Colors.white54),
      ],
    );
  }

  Widget _signatureLabel({required bool onDark}) {
    if (signature.trim().isEmpty) return const SizedBox.shrink();
    return Text(
      '— ${signature.trim()}',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: onDark ? Colors.white : const Color(0xFF173D32),
        fontSize: 22,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w600,
        shadows: onDark
            ? [
                Shadow(
                  color: Colors.black.withValues(alpha: .4),
                  blurRadius: 4,
                ),
              ]
            : null,
      ),
    );
  }

  /// Cuma theme: elegant gradient, mosque silhouette, floral decor
  Widget _buildCumaCard() {
    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFDBEAFE),
            Color(0xFFEFF6FF),
            Color(0xFFFDE68A),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          _buildImageBackground(),
          _buildImageOverlay(),
          if (_hasImage)
            Positioned(top: 34, right: 34, child: _imageBrandBadge()),
          // Mosque silhouette
          const Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: 0.18,
              child: Icon(
                Icons.mosque,
                size: 200,
                color: Color(0xFF1E3A8A),
              ),
            ),
          ),
          // Floral accents
          Positioned(
            top: 50,
            left: 50,
            child: Icon(Icons.local_florist,
                size: 55,
                color: const Color(0xFF1E40AF).withValues(alpha: 0.5)),
          ),
          Positioned(
            bottom: 100,
            right: 55,
            child: Icon(Icons.local_florist,
                size: 42,
                color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
          ),
          // Main content - görsel varsa altta karartılmış alan üzerinde beyaz metin
          imageUrl != null && imageUrl!.isNotEmpty
              ? Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildTextContainer(
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildMessageContent(38, const Color(0xFF1E3A8A),
                            hasImage: true),
                        const SizedBox(height: 30),
                        _messageAttribution(),
                        if (signature.trim().isNotEmpty) ...[
                          const SizedBox(height: 22),
                          _signatureLabel(onDark: true),
                        ],
                      ],
                    ),
                  ),
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 60, vertical: 80),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMessageContent(40, const Color(0xFF1E3A8A)),
                        if (signature.trim().isNotEmpty) ...[
                          const SizedBox(height: 28),
                          _signatureLabel(onDark: false),
                        ],
                        const SizedBox(height: 60),
                        _appBadge(),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  /// Kandil theme: warm gold/beige, lantern/crescent
  Widget _buildKandilCard() {
    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFF8F4E8),
            Color(0xFFFDF9ED),
            Color(0xFFF5EDE0),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          _buildImageBackground(),
          _buildImageOverlay(),
          if (_hasImage)
            Positioned(top: 34, right: 34, child: _imageBrandBadge()),
          // Lantern/crescent decorations
          Positioned(
            top: 55,
            left: 65,
            child: Icon(Icons.nightlight_round,
                size: 52,
                color: const Color(0xFFB8860B).withValues(alpha: 0.6)),
          ),
          Positioned(
            top: 85,
            right: 75,
            child: Icon(Icons.star,
                size: 38,
                color: const Color(0xFFC9A227).withValues(alpha: 0.55)),
          ),
          Positioned(
            bottom: 85,
            left: 55,
            child: Icon(Icons.nightlight_round,
                size: 44,
                color: const Color(0xFFD4A84B).withValues(alpha: 0.45)),
          ),
          // Main content
          imageUrl != null && imageUrl!.isNotEmpty
              ? Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildTextContainer(
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildMessageContent(36, const Color(0xFF2C2416),
                            hasImage: true),
                        const SizedBox(height: 30),
                        _messageAttribution(),
                        if (signature.trim().isNotEmpty) ...[
                          const SizedBox(height: 22),
                          _signatureLabel(onDark: true),
                        ],
                      ],
                    ),
                  ),
                )
              : Center(
                  child: Container(
                    margin: const EdgeInsets.all(55),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 45, vertical: 50),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFC9A227).withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMessageContent(36, const Color(0xFF2C2416)),
                        if (signature.trim().isNotEmpty) ...[
                          const SizedBox(height: 28),
                          _signatureLabel(onDark: false),
                        ],
                        const SizedBox(height: 50),
                        _appBadge(),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  /// Bayram theme: clean white, festive pastel accents
  Widget _buildBayramCard() {
    final positions = [
      const Offset(0.08, 0.1),
      const Offset(0.15, 0.2),
      const Offset(0.25, 0.12),
      const Offset(0.85, 0.15),
      const Offset(0.90, 0.25),
      const Offset(0.80, 0.35),
      const Offset(0.10, 0.70),
      const Offset(0.20, 0.80),
      const Offset(0.85, 0.75),
      const Offset(0.48, 0.10),
      const Offset(0.42, 0.88),
      const Offset(0.52, 0.15),
    ];
    final colors = [
      const Color(0xFFFFD700),
      const Color(0xFF87CEEB),
      const Color(0xFFFFB6C1),
      const Color(0xFF98FB98),
      const Color(0xFFDDA0DD),
    ];

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.12),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        children: [
          _buildImageBackground(),
          _buildImageOverlay(),
          if (_hasImage)
            Positioned(top: 34, right: 34, child: _imageBrandBadge()),
          // Star confetti (positions as fractions)
          ...List.generate(12, (i) {
            final p = positions[i];
            return Positioned(
              left: width * p.dx - 12,
              top: height * p.dy - 12,
              child: Icon(
                Icons.star,
                size: 18 + (i % 3) * 4,
                color: colors[i % colors.length].withValues(alpha: 0.6),
              ),
            );
          }),
          // Main content
          imageUrl != null && imageUrl!.isNotEmpty
              ? Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildTextContainer(
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildMessageContent(36, const Color(0xFF2C3E50),
                            hasImage: true),
                        const SizedBox(height: 30),
                        _messageAttribution(),
                        if (signature.trim().isNotEmpty) ...[
                          const SizedBox(height: 22),
                          _signatureLabel(onDark: true),
                        ],
                      ],
                    ),
                  ),
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 60, vertical: 80),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMessageContent(36, const Color(0xFF2C3E50)),
                        if (signature.trim().isNotEmpty) ...[
                          const SizedBox(height: 28),
                          _signatureLabel(onDark: false),
                        ],
                        const SizedBox(height: 60),
                        _appBadge(),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _appBadge({bool compact = false, bool onDark = false}) {
    return Text(
      'Her Gün İslam',
      style: TextStyle(
        fontSize: compact ? 18 : 22,
        color: onDark ? Colors.white70 : Colors.grey[600],
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
