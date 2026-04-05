import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/surah_ayah_detail.dart';

/// Ayet kartı: Arapça (sağ, büyük), Türkçe meal, alt satırda aksiyonlar.
class SurahAyahCard extends StatelessWidget {
  final SurahAyahDetail ayah;
  final String surahName;
  final bool highlightActive;
  final bool isPlaying;
  final bool hasAudio;
  final bool isFavorite;
  final VoidCallback onPlayPause;
  final VoidCallback onShare;
  final VoidCallback onCopy;
  final VoidCallback onFavorite;

  const SurahAyahCard({
    super.key,
    required this.ayah,
    required this.surahName,
    required this.highlightActive,
    required this.isPlaying,
    required this.hasAudio,
    required this.isFavorite,
    required this.onPlayPause,
    required this.onShare,
    required this.onCopy,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    const baseBg = Colors.white;
    const activeBg = Color(0xFFDBEAFE);
    final borderColor = highlightActive
        ? const Color(0xFF1E40AF).withValues(alpha: 0.35)
        : Colors.grey.shade200;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: highlightActive ? activeBg : baseBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: highlightActive ? 1.5 : 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 16,
                offset: const Offset(0, 6),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E40AF).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${ayah.numberInSurah}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      surahName,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  ayah.arabicText,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: GoogleFonts.amiriQuran(
                    fontSize: 26,
                    height: 1.75,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  ayah.turkishText,
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.55,
                    color: Colors.grey.shade800,
                    fontFamily: 'Segoe UI',
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ActionIcon(
                      tooltip: hasAudio
                          ? (isPlaying ? 'Duraklat' : 'Oynat')
                          : 'Ses yok',
                      icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      onPressed: hasAudio ? onPlayPause : null,
                      active: highlightActive && isPlaying,
                    ),
                    _ActionIcon(
                      tooltip: 'Paylaş',
                      icon: Icons.share_outlined,
                      onPressed: onShare,
                    ),
                    _ActionIcon(
                      tooltip: 'Kopyala',
                      icon: Icons.copy_outlined,
                      onPressed: onCopy,
                    ),
                    _ActionIcon(
                      tooltip: isFavorite ? 'Favorilerden çıkar' : 'Favorilere ekle',
                      icon: isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                      onPressed: onFavorite,
                      active: isFavorite,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool active;

  const _ActionIcon({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = onPressed == null
        ? Colors.grey.shade400
        : (active ? const Color(0xFF1E40AF) : const Color(0xFF1E3A8A));

    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 26, color: color),
        splashRadius: 22,
      ),
    );
  }
}
