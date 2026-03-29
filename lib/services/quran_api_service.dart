import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../data/quran_surah_names_tr.dart';
import '../models/daily_item.dart';

/// Service for fetching Quran Ayahs from Al-Quran Cloud API
/// Free API: https://api.alquran.cloud/v1
class QuranApiService {
  static const String baseUrl = 'https://api.alquran.cloud/v1';
  static const Duration timeoutDuration = Duration(seconds: 10);
  final Random _random = Random();

  /// Fetch a random Ayah from Quran with Turkish translation
  Future<DailyItem?> fetchRandomAyah() async {
    try {
      // Get random surah (1-114)
      final surah = _random.nextInt(114) + 1;
      
      // First, get surah info to know how many ayahs it has
      final surahInfo = await _getSurahInfo(surah);
      if (surahInfo == null) return null;
      
      final ayahCount = surahInfo['numberOfAyahs'] as int;
      final ayah = _random.nextInt(ayahCount) + 1;
      
      // Get Arabic text
      final arabicUri = Uri.parse('$baseUrl/ayah/$surah:$ayah/quran-uthmani');
      final arabicResponse = await http.get(arabicUri).timeout(timeoutDuration);
      
      String arabicText = '';
      if (arabicResponse.statusCode == 200) {
        final arabicData = json.decode(arabicResponse.body);
        arabicText = arabicData['data']['text'] as String? ?? '';
      }
      
      // Get Turkish translation - try multiple Turkish translation endpoints
      String translationText = '';
      final turkishEditions = ['tr.diyanet', 'tr.yazir', 'tr.bayraktar'];
      
      for (final edition in turkishEditions) {
        try {
          final translationUri = Uri.parse('$baseUrl/ayah/$surah:$ayah/$edition');
          final translationResponse = await http.get(translationUri).timeout(timeoutDuration);
          
          if (translationResponse.statusCode == 200) {
            final translationData = json.decode(translationResponse.body);
            final data = translationData['data'];
            
            // API response structure: data['text'] contains the translation
            String? text;
            if (data != null) {
              // Try data['text'] first (most common structure)
              if (data['text'] != null) {
                text = data['text'] as String?;
              }
              // Alternative: data['edition']['text']
              else if (data['edition'] != null) {
                final editionData = data['edition'];
                if (editionData is Map && editionData['text'] != null) {
                  text = editionData['text'] as String?;
                }
              }
            }
            
            // Check if it's actually Turkish (not Arabic)
            if (text != null && text.isNotEmpty && !_isArabic(text)) {
              translationText = text;
              break;
            }
          }
        } catch (e) {
          continue;
        }
      }
      
      // If still no translation, try surah endpoint
      if (translationText.isEmpty) {
        try {
          final surahUri = Uri.parse('$baseUrl/surah/$surah/tr.diyanet');
          final surahResponse = await http.get(surahUri).timeout(timeoutDuration);
          
          if (surahResponse.statusCode == 200) {
            final surahData = json.decode(surahResponse.body);
            final ayahs = surahData['data']['ayahs'] as List?;
            
            if (ayahs != null && ayah <= ayahs.length && ayah > 0) {
              final ayahObj = ayahs[ayah - 1];
              if (ayahObj['text'] != null) {
                final text = ayahObj['text'] as String;
                if (!_isArabic(text)) {
                  translationText = text;
                }
              }
            }
          }
        } catch (e) {}
      }
      
      // Get Turkish surah name
      final turkishSurahName = kQuranTurkishSurahNames[surah] ?? 'Sure $surah';
      
      // Combine Arabic and Turkish
      String displayText = '';
      if (arabicText.isNotEmpty) {
        displayText = arabicText;
        if (translationText.isNotEmpty) {
          displayText += '\n\n$translationText';
        }
      } else if (translationText.isNotEmpty) {
        displayText = translationText;
      } else {
        return null;
      }
      
      return DailyItem(
        type: 'ayah',
        text: displayText,
        source: '$turkishSurahName Suresi $ayah',
      );
    } catch (e) {}
    return null;
  }

  /// Check if text contains Arabic characters
  bool _isArabic(String text) {
    // Arabic Unicode range: U+0600 to U+06FF
    final arabicRegex = RegExp(r'[\u0600-\u06FF]');
    return arabicRegex.hasMatch(text);
  }

  /// Get surah information
  Future<Map<String, dynamic>?> _getSurahInfo(int surahNumber) async {
    try {
      final uri = Uri.parse('$baseUrl/surah/$surahNumber');
      final response = await http.get(uri).timeout(timeoutDuration);
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return jsonData['data'] as Map<String, dynamic>?;
      }
    } catch (e) {}
    return null;
  }

  /// Fetch a specific Ayah
  Future<DailyItem?> fetchAyah(int surah, int ayah) async {
    try {
      // Get Arabic text
      final arabicUri = Uri.parse('$baseUrl/ayah/$surah:$ayah/quran-uthmani');
      final arabicResponse = await http.get(arabicUri).timeout(timeoutDuration);
      
      String arabicText = '';
      if (arabicResponse.statusCode == 200) {
        final arabicData = json.decode(arabicResponse.body);
        arabicText = arabicData['data']['text'] as String? ?? '';
      }
      
      // Get Turkish translation
      String translationText = '';
      final turkishEditions = ['tr.diyanet', 'tr.yazir', 'tr.bayraktar'];
      
      for (final edition in turkishEditions) {
        try {
          final translationUri = Uri.parse('$baseUrl/ayah/$surah:$ayah/$edition');
          final translationResponse = await http.get(translationUri).timeout(timeoutDuration);
          
          if (translationResponse.statusCode == 200) {
            final translationData = json.decode(translationResponse.body);
            final data = translationData['data'];
            
            String? text;
            if (data != null) {
              if (data['text'] != null) {
                text = data['text'] as String?;
              } else if (data['edition'] != null && data['edition']['text'] != null) {
                text = data['edition']['text'] as String?;
              }
            }
            
            if (text != null && text.isNotEmpty && !_isArabic(text)) {
              translationText = text;
              break;
            }
          }
        } catch (e) {
          continue;
        }
      }
      
      // If still no translation, try surah endpoint
      if (translationText.isEmpty) {
        try {
          final surahUri = Uri.parse('$baseUrl/surah/$surah/tr.diyanet');
          final surahResponse = await http.get(surahUri).timeout(timeoutDuration);
          
          if (surahResponse.statusCode == 200) {
            final surahData = json.decode(surahResponse.body);
            final ayahs = surahData['data']['ayahs'] as List?;
            
            if (ayahs != null && ayah <= ayahs.length && ayah > 0) {
              final ayahObj = ayahs[ayah - 1];
              if (ayahObj['text'] != null) {
                final text = ayahObj['text'] as String;
                if (!_isArabic(text)) {
                  translationText = text;
                }
              }
            }
          }
        } catch (e) {}
      }
      
      final turkishSurahName = kQuranTurkishSurahNames[surah] ?? 'Sure $surah';
      
      String displayText = '';
      if (arabicText.isNotEmpty) {
        displayText = arabicText;
        if (translationText.isNotEmpty) {
          displayText += '\n\n$translationText';
        }
      } else if (translationText.isNotEmpty) {
        displayText = translationText;
      }
      
      return DailyItem(
        type: 'ayah',
        text: displayText,
        source: '$turkishSurahName Suresi $ayah',
      );
    } catch (e) {}
    return null;
  }

  /// Fetch entire surah
  Future<List<DailyItem>> fetchSurah(int surahNumber) async {
    try {
      final uri = Uri.parse('$baseUrl/surah/$surahNumber/tr.bayraktar');
      final response = await http.get(uri).timeout(timeoutDuration);
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final surahData = jsonData['data'];
        final ayahs = surahData['ayahs'] as List;
        final turkishSurahName =
            kQuranTurkishSurahNames[surahNumber] ?? 'Sure $surahNumber';
        
        return ayahs.map((ayah) {
          return DailyItem(
            type: 'ayah',
            text: '${ayah['text'] ?? ''}',
            source: '$turkishSurahName Suresi ${ayah['numberInSurah']}',
          );
        }).toList();
      }
    } catch (e) {}
    return [];
  }
}
