import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/daily_item.dart';

/// Service for fetching Quran Ayahs from Al-Quran Cloud API
/// Free API: https://api.alquran.cloud/v1
class QuranApiService {
  static const String baseUrl = 'https://api.alquran.cloud/v1';
  static const Duration timeoutDuration = Duration(seconds: 10);
  final Random _random = Random();

  // Turkish surah names mapping
  static const Map<int, String> _turkishSurahNames = {
    1: 'Fatiha',
    2: 'Bakara',
    3: 'Al-i İmran',
    4: 'Nisa',
    5: 'Maide',
    6: 'Enam',
    7: 'Araf',
    8: 'Enfal',
    9: 'Tevbe',
    10: 'Yunus',
    11: 'Hud',
    12: 'Yusuf',
    13: 'Rad',
    14: 'İbrahim',
    15: 'Hicr',
    16: 'Nahl',
    17: 'İsra',
    18: 'Kehf',
    19: 'Meryem',
    20: 'Taha',
    21: 'Enbiya',
    22: 'Hac',
    23: 'Muminun',
    24: 'Nur',
    25: 'Furkan',
    26: 'Şuara',
    27: 'Neml',
    28: 'Kasas',
    29: 'Ankebut',
    30: 'Rum',
    31: 'Lokman',
    32: 'Secde',
    33: 'Ahzab',
    34: 'Sebe',
    35: 'Fatır',
    36: 'Yasin',
    37: 'Saffat',
    38: 'Sad',
    39: 'Zumer',
    40: 'Mümin',
    41: 'Fussilet',
    42: 'Şura',
    43: 'Zuhruf',
    44: 'Duhan',
    45: 'Casiye',
    46: 'Ahkaf',
    47: 'Muhammed',
    48: 'Fetih',
    49: 'Hucurat',
    50: 'Kaf',
    51: 'Zariyat',
    52: 'Tur',
    53: 'Necm',
    54: 'Kamer',
    55: 'Rahman',
    56: 'Vakıa',
    57: 'Hadid',
    58: 'Mücadele',
    59: 'Haşr',
    60: 'Mümtehine',
    61: 'Saf',
    62: 'Cuma',
    63: 'Münafikun',
    64: 'Teğabun',
    65: 'Talak',
    66: 'Tahrim',
    67: 'Mülk',
    68: 'Kalem',
    69: 'Hakka',
    70: 'Mearic',
    71: 'Nuh',
    72: 'Cin',
    73: 'Müzzemmil',
    74: 'Müddessir',
    75: 'Kıyame',
    76: 'İnsan',
    77: 'Mürselat',
    78: 'Nebe',
    79: 'Naziat',
    80: 'Abese',
    81: 'Tekvir',
    82: 'İnfitar',
    83: 'Mutaffifin',
    84: 'İnşikak',
    85: 'Buruc',
    86: 'Tarık',
    87: 'Ala',
    88: 'Gaşiye',
    89: 'Fecr',
    90: 'Beled',
    91: 'Şems',
    92: 'Leyl',
    93: 'Duha',
    94: 'İnşirah',
    95: 'Tin',
    96: 'Alak',
    97: 'Kadir',
    98: 'Beyyine',
    99: 'Zilzal',
    100: 'Adiyat',
    101: 'Karia',
    102: 'Tekasür',
    103: 'Asr',
    104: 'Hümeze',
    105: 'Fil',
    106: 'Kureyş',
    107: 'Maun',
    108: 'Kevser',
    109: 'Kafirun',
    110: 'Nasr',
    111: 'Tebbet',
    112: 'İhlas',
    113: 'Felak',
    114: 'Nas',
  };

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
      final turkishSurahName = _turkishSurahNames[surah] ?? 'Sure $surah';
      
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
      
      final turkishSurahName = _turkishSurahNames[surah] ?? 'Sure $surah';
      
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
        final turkishSurahName = _turkishSurahNames[surahNumber] ?? 'Sure $surahNumber';
        
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
