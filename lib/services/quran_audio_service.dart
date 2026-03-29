import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for fetching Quran audio from quranapi.pages.dev
/// Free API, no rate limits, 5 reciters available
class QuranAudioService {
  static const String baseUrl = 'https://quranapi.pages.dev/api';
  static const Duration timeoutDuration = Duration(seconds: 20); // Increased for slow networks

  // Memory cache for audio URLs to avoid repeated API calls
  static final Map<String, String> _urlCache = {};

  /// Reciter IDs: 1-5 for quranapi.pages.dev, 7 for Quran Foundation API (timing compatible).
  /// ID 7 is mapped to API key 5 (Hani Ar Rifai) in [audioApiReciterKey] — the JSON has no "7" entry.
  static const Map<int, String> reciters = {
    1: 'Mishary Rashid Al Afasy',
    2: 'Abu Bakr Al Shatri',
    3: 'Nasser Al Qatami',
    4: 'Yasser Al Dosari',
    5: 'Hani Ar Rifai',
    7: 'Hani Ar Rifai', // Timing compatible with Quran Foundation API
  };

  /// Maps UI / timing reciter id to quranapi.pages.dev JSON keys (only "1".."5").
  /// Default Hani (Quran Foundation id 7) → API bucket 5.
  static int audioApiReciterKey(int reciterId) {
    if (reciterId == 7) return 5;
    if (reciterId >= 1 && reciterId <= 5) return reciterId;
    return 5;
  }

  /// Turkish surah names
  static const Map<int, String> turkishSurahNames = {
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

  /// mp3quran.net bases (same as quranapi JSON [originalUrl]) — works on old Android MediaPlayer; GitHub raw often does not.
  static const Map<int, String> _mp3quranBaseByApiKey = {
    1: 'https://server8.mp3quran.net/afs/',
    2: 'https://server11.mp3quran.net/shatri/',
    3: 'https://server6.mp3quran.net/qtm/',
    4: 'https://server11.mp3quran.net/yasser/',
    5: 'https://server8.mp3quran.net/hani/',
  };

  /// When the HTTP API fails: same CDN as [originalUrl] (3-digit surah names).
  static String _getFallbackUrl(int surahNumber, int reciterId) {
    final key = audioApiReciterKey(reciterId);
    final padded = surahNumber.toString().padLeft(3, '0');
    final base = _mp3quranBaseByApiKey[key];
    if (base != null) {
      return '$base$padded.mp3';
    }
    return 'https://server8.mp3quran.net/hani/$padded.mp3';
  }

  /// Fetch full chapter (surah) audio URL for a reciter
  /// Use this for playing entire surah - /audio/{surah}.json
  Future<String?> fetchSurahAudioUrl({
    required int surahNumber,
    required int reciterId,
  }) async {
    // Check memory cache first (drop stale GitHub URLs from older app versions)
    final cacheKey = '${surahNumber}_$reciterId';
    if (_urlCache.containsKey(cacheKey)) {
      final cached = _urlCache[cacheKey]!;
      if (cached.contains('githubusercontent.com') ||
          cached.contains('github.com/The-Quran-Project')) {
        _urlCache.remove(cacheKey);
      } else {
        return cached;
      }
    }

    try {
      final uri = Uri.parse('$baseUrl/audio/$surahNumber.json');
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'HerGunIslam/1.0 (Android)',
          'Accept': 'application/json',
          'Cache-Control': 'max-age=86400', // Cache for 24 hours
        },
      ).timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final apiKey = audioApiReciterKey(reciterId);
        final reciterObj = data[apiKey.toString()] as Map<String, dynamic>?;
        if (reciterObj != null) {
          final ghUrl = reciterObj['url'] as String?;
          final originalUrl = reciterObj['originalUrl'] as String?;
          // Prefer mp3quran CDN — Android ExoPlayer/MediaPlayer streams reliably; GitHub HTML/redirect URLs often fail.
          final resultUrl = originalUrl ?? ghUrl;

          if (resultUrl != null) {
            _urlCache[cacheKey] = resultUrl;
            return resultUrl;
          }
        }
      }
    } catch (e) {
      // Silently fail, will try fallback
    }
    
    final fallbackUrl = _getFallbackUrl(surahNumber, reciterId);
    _urlCache[cacheKey] = fallbackUrl;
    return fallbackUrl;
  }

  /// Get list of all 114 surahs for display
  List<QuranSurahInfo> getAllSurahs() {
    return List.generate(114, (i) {
      final num = i + 1;
      return QuranSurahInfo(
        number: num,
        name: turkishSurahNames[num] ?? 'Sure $num',
      );
    });
  }
}

/// Simple model for surah info
class QuranSurahInfo {
  final int number;
  final String name;

  QuranSurahInfo({required this.number, required this.name});
}
