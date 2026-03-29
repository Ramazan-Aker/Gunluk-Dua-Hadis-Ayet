/// Single ayah row for surah detail: Arabic, Turkish (Diyanet), and optional Alafasy stream URL(s).
class SurahAyahDetail {
  final int globalAyahNumber;
  final int numberInSurah;
  final String arabicText;
  final String turkishText;

  /// Sırayla denenecek ses URL’leri (genelde 128 kbps, sonra 64 / API yedekleri).
  final List<String> audioCandidateUrls;

  const SurahAyahDetail({
    required this.globalAyahNumber,
    required this.numberInSurah,
    required this.arabicText,
    required this.turkishText,
    this.audioCandidateUrls = const [],
  });

  /// İlk aday URL (kart / uyumluluk).
  String? get audioUrl =>
      audioCandidateUrls.isEmpty ? null : audioCandidateUrls.first;

  String get shareSnippet {
    final a = arabicText.trim();
    final t = turkishText.trim();
    if (t.isEmpty) return a;
    return '$a\n\n$t';
  }

  String favoriteKey(int surahNumber) => '$surahNumber:$numberInSurah';
}
