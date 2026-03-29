/// Tek ayet: `assets/quran_offline.json` satırı.
class QuranOfflineVerse {
  final int surah;
  final int ayahInSurah;
  final int globalAyah;
  final String arabic;
  final String turkish;
  final String footer;

  const QuranOfflineVerse({
    required this.surah,
    required this.ayahInSurah,
    required this.globalAyah,
    required this.arabic,
    required this.turkish,
    required this.footer,
  });
}
