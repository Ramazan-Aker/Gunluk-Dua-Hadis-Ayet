import 'verse_timing.dart';

/// Single response from Quran.com: chapter audio URL + verse timings (same file).
class ChapterRecitationResult {
  final String? audioUrl;
  final List<VerseTiming> timings;
  final int quranComReciterId;

  const ChapterRecitationResult({
    required this.audioUrl,
    required this.timings,
    required this.quranComReciterId,
  });

  bool get hasSyncData =>
      audioUrl != null &&
      audioUrl!.isNotEmpty &&
      timings.isNotEmpty;
}
