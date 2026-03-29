import 'package:flutter/material.dart';
import '../models/quran_verse.dart';

/// Widget to display a single Quran verse with Arabic text and Turkish translation
/// Supports word-by-word highlighting during audio playback
class QuranVerseWidget extends StatelessWidget {
  final QuranVerse verse;
  final bool isCurrentVerse; // Is this verse currently being played?
  final int? highlightedWordIndex; // Index of currently highlighted word (0-based)
  final double arabicFontSize;
  final double turkishFontSize;
  final VoidCallback? onTap;

  const QuranVerseWidget({
    super.key,
    required this.verse,
    this.isCurrentVerse = false,
    this.highlightedWordIndex,
    this.arabicFontSize = 26.0,
    this.turkishFontSize = 16.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Color(0xFFF0FDFA),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isCurrentVerse 
              ? const Color(0xFF0D9488).withOpacity(0.15)
              : Colors.grey.withOpacity(0.08),
            blurRadius: isCurrentVerse ? 12 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        elevation: 0,
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isCurrentVerse ? const Color(0xFF0D9488) : Colors.grey.shade200,
            width: isCurrentVerse ? 2.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Verse number badge - more compact
                _buildVerseNumberBadge(),
                
                const SizedBox(height: 16),
                
                // Arabic text with word highlighting
                _buildArabicText(context),
                
                const SizedBox(height: 12),
                
                // Divider
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.grey.shade200,
                        const Color(0xFF0D9488).withOpacity(0.3),
                        Colors.grey.shade200,
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Turkish translation
                _buildTurkishText(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerseNumberBadge() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF0D9488).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '${verse.numberInSurah}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D9488),
            ),
          ),
        ),
        if (isCurrentVerse)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.volume_up, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text(
                  'Okunuyor',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildArabicText(BuildContext context) {
    if (verse.arabicWords.isEmpty) {
      return Text(
        verse.arabicText,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: arabicFontSize,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1F2937),
          height: 1.9,
          letterSpacing: 0.5,
        ),
      );
    }

    // Build word-by-word with highlighting
    return RichText(
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
      text: TextSpan(
        children: verse.arabicWords.asMap().entries.map((entry) {
          final index = entry.key;
          final word = entry.value;
          final isHighlighted = highlightedWordIndex == index;

          return TextSpan(
            text: '$word ',
            style: TextStyle(
              fontSize: arabicFontSize,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1F2937),
              height: 1.9,
              letterSpacing: 0.5,
              backgroundColor: isHighlighted
                  ? const Color(0xFFFBBF24).withOpacity(0.4)
                  : Colors.transparent,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTurkishText() {
    return Text(
      verse.turkishText,
      style: TextStyle(
        fontSize: turkishFontSize,
        color: Colors.grey.shade700,
        height: 1.5,
      ),
    );
  }
}

/// Skeleton loading widget for verses (while data is loading)
class QuranVerseSkeletonWidget extends StatelessWidget {
  const QuranVerseSkeletonWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Verse number
            Container(
              width: 32,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 12),
            // Arabic text lines
            _buildShimmerLine(width: double.infinity, height: 20),
            const SizedBox(height: 6),
            _buildShimmerLine(width: double.infinity, height: 20),
            const SizedBox(height: 6),
            _buildShimmerLine(width: 200, height: 20),
            const SizedBox(height: 8),
            // Divider
            Container(
              height: 1,
              color: Colors.grey.shade200,
            ),
            const SizedBox(height: 8),
            // Turkish text lines
            _buildShimmerLine(width: double.infinity, height: 14),
            const SizedBox(height: 4),
            _buildShimmerLine(width: 180, height: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLine({required double width, double height = 24}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
