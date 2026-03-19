/// Model for a Quran verse with Arabic text and Turkish translation
class QuranVerse {
  final int number; // Global verse number (1-6236)
  final int numberInSurah; // Verse number within the surah
  final String arabicText; // Full Arabic text
  final List<String> arabicWords; // Arabic words split by space
  final String turkishText; // Turkish translation

  QuranVerse({
    required this.number,
    required this.numberInSurah,
    required this.arabicText,
    required this.arabicWords,
    required this.turkishText,
  });

  /// Factory constructor from Al-Quran Cloud API response
  factory QuranVerse.fromJson(Map<String, dynamic> arabicJson, Map<String, dynamic> turkishJson) {
    final arabicText = arabicJson['text'] as String? ?? '';
    
    // Split Arabic text by space to get words
    // Filter out empty strings
    final words = arabicText
        .split(' ')
        .where((word) => word.trim().isNotEmpty)
        .toList();

    return QuranVerse(
      number: arabicJson['number'] as int? ?? 0,
      numberInSurah: arabicJson['numberInSurah'] as int? ?? 0,
      arabicText: arabicText,
      arabicWords: words,
      turkishText: turkishJson['text'] as String? ?? '',
    );
  }

  /// Create a copy with updated fields
  QuranVerse copyWith({
    int? number,
    int? numberInSurah,
    String? arabicText,
    List<String>? arabicWords,
    String? turkishText,
  }) {
    return QuranVerse(
      number: number ?? this.number,
      numberInSurah: numberInSurah ?? this.numberInSurah,
      arabicText: arabicText ?? this.arabicText,
      arabicWords: arabicWords ?? this.arabicWords,
      turkishText: turkishText ?? this.turkishText,
    );
  }

  @override
  String toString() {
    return 'QuranVerse(number: $number, numberInSurah: $numberInSurah, wordsCount: ${arabicWords.length})';
  }
}
