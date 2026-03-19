import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/quran_verse.dart';

/// Service for fetching Quran text (Arabic + Turkish) from Al-Quran Cloud API
class QuranTextService {
  static const String baseUrl = 'https://api.alquran.cloud/v1';
  static const Duration timeoutDuration = Duration(seconds: 15);

  // Edition identifiers
  static const String arabicEdition = 'quran-uthmani'; // Uthmani script
  static const String turkishEdition = 'tr.diyanet'; // Diyanet translation

  /// Fetch a complete surah with Arabic text and Turkish translation
  Future<List<QuranVerse>> fetchSurah(int surahNumber) async {
    try {
      // Fetch both Arabic and Turkish in parallel
      final responses = await Future.wait([
        _fetchSurahEdition(surahNumber, arabicEdition),
        _fetchSurahEdition(surahNumber, turkishEdition),
      ]);

      final arabicResponse = responses[0];
      final turkishResponse = responses[1];

      if (arabicResponse == null || turkishResponse == null) {
        return [];
      }

      final arabicData = arabicResponse['data'] as Map<String, dynamic>;
      final turkishData = turkishResponse['data'] as Map<String, dynamic>;

      final arabicAyahs = arabicData['ayahs'] as List<dynamic>;
      final turkishAyahs = turkishData['ayahs'] as List<dynamic>;

      if (arabicAyahs.length != turkishAyahs.length) {
        throw Exception('Verse count mismatch between Arabic and Turkish');
      }

      // Create QuranVerse objects by combining Arabic and Turkish data
      final verses = <QuranVerse>[];
      for (int i = 0; i < arabicAyahs.length; i++) {
        final arabicAyah = arabicAyahs[i] as Map<String, dynamic>;
        final turkishAyah = turkishAyahs[i] as Map<String, dynamic>;
        
        verses.add(QuranVerse.fromJson(arabicAyah, turkishAyah));
      }

      return verses;
    } catch (e) {
      // Log error (could use Firebase Crashlytics here)
      return [];
    }
  }

  /// Fetch a single surah edition (Arabic or Turkish)
  Future<Map<String, dynamic>?> _fetchSurahEdition(
    int surahNumber,
    String edition,
  ) async {
    try {
      final uri = Uri.parse('$baseUrl/surah/$surahNumber/$edition');
      final response = await http.get(uri).timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        
        // API returns {code: 200, status: "OK", data: {...}}
        if (jsonData['code'] == 200 && jsonData['data'] != null) {
          return jsonData;
        }
      }
    } catch (e) {
      // Silently fail, caller will handle null
    }
    return null;
  }

  /// Fetch a single verse (for testing or specific use cases)
  Future<QuranVerse?> fetchVerse(int surahNumber, int verseNumber) async {
    try {
      final responses = await Future.wait([
        _fetchVerseEdition(surahNumber, verseNumber, arabicEdition),
        _fetchVerseEdition(surahNumber, verseNumber, turkishEdition),
      ]);

      final arabicResponse = responses[0];
      final turkishResponse = responses[1];

      if (arabicResponse == null || turkishResponse == null) {
        return null;
      }

      final arabicData = arabicResponse['data'] as Map<String, dynamic>;
      final turkishData = turkishResponse['data'] as Map<String, dynamic>;

      return QuranVerse.fromJson(arabicData, turkishData);
    } catch (e) {
      return null;
    }
  }

  /// Fetch a single verse edition
  Future<Map<String, dynamic>?> _fetchVerseEdition(
    int surahNumber,
    int verseNumber,
    String edition,
  ) async {
    try {
      final uri = Uri.parse('$baseUrl/ayah/$surahNumber:$verseNumber/$edition');
      final response = await http.get(uri).timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        
        if (jsonData['code'] == 200 && jsonData['data'] != null) {
          return jsonData;
        }
      }
    } catch (e) {
      // Silently fail
    }
    return null;
  }

  /// Get surah info (name, number of verses, etc.)
  Future<Map<String, dynamic>?> getSurahInfo(int surahNumber) async {
    try {
      final uri = Uri.parse('$baseUrl/surah/$surahNumber');
      final response = await http.get(uri).timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        
        if (jsonData['code'] == 200 && jsonData['data'] != null) {
          final data = jsonData['data'] as Map<String, dynamic>;
          return {
            'number': data['number'],
            'name': data['name'],
            'englishName': data['englishName'],
            'englishNameTranslation': data['englishNameTranslation'],
            'numberOfAyahs': data['numberOfAyahs'],
            'revelationType': data['revelationType'],
          };
        }
      }
    } catch (e) {
      // Silently fail
    }
    return null;
  }
}
