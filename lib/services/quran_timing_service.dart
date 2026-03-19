import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/verse_timing.dart';

/// Service for fetching word-by-word timing data from Quran Foundation API
class QuranTimingService {
  static const String baseUrl = 'https://api.quran.com/api/v4';
  static const Duration timeoutDuration = Duration(seconds: 20); // Increased for slow networks

  // Reciter IDs - will be confirmed from API
  // Hani Ar Rifai is typically ID 5 or 7 in Quran Foundation API
  static const int haniArRifaiReciterId = 7;

  // Cache keys
  static const String _cacheKeyPrefix = 'quran_timing_';

  /// Fetch chapter timings with word-level segments
  Future<List<VerseTiming>> fetchChapterTimings({
    required int chapterNumber,
    int? reciterId,
    bool useCache = true,
  }) async {
    final effectiveReciterId = reciterId ?? haniArRifaiReciterId;

    // Try cache first
    if (useCache) {
      final cached = await _getCachedTimings(chapterNumber, effectiveReciterId);
      if (cached != null) {
        print('✅ Timing from cache: Chapter $chapterNumber');
        return cached;
      }
    }

    try {
      // Fetch from API with segments=true parameter
      final uri = Uri.parse(
        '$baseUrl/chapter_recitations/$effectiveReciterId/$chapterNumber?segments=true',
      );

      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
        'Cache-Control': 'max-age=86400', // Cache for 24 hours
      }).timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        
        // API response structure: {audio_file: {id, chapter_id, file_size, format, audio_url, timestamps: [...]}}
        final audioFile = jsonData['audio_file'] as Map<String, dynamic>?;
        if (audioFile == null) {
          print('⚠️ No audio_file in response for Chapter $chapterNumber');
          return [];
        }

        final timestamps = audioFile['timestamps'] as List<dynamic>?;
        if (timestamps == null || timestamps.isEmpty) {
          print('⚠️ No timestamps in response for Chapter $chapterNumber');
          return [];
        }

        // Parse timestamps into VerseTiming objects
        final timings = timestamps
            .map((t) => VerseTiming.fromJson(t as Map<String, dynamic>))
            .toList();

        // Cache the result
        await _cacheTimings(chapterNumber, effectiveReciterId, timings);

        print('✅ Timing fetched from API: Chapter $chapterNumber (${timings.length} verses)');
        return timings;
      } else {
        print('❌ Timing API error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Timing fetch error: $e');
    }

    return [];
  }

  /// Get cached timings from SharedPreferences
  Future<List<VerseTiming>?> _getCachedTimings(int chapterNumber, int reciterId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix${chapterNumber}_$reciterId';
      final cachedJson = prefs.getString(cacheKey);

      if (cachedJson != null) {
        final cache = ChapterTimingCache.fromJsonString(cachedJson);
        
        // Check if cache is still valid (7 days)
        if (cache.isValid()) {
          return cache.timings;
        } else {
          // Remove expired cache
          await prefs.remove(cacheKey);
        }
      }
    } catch (e) {
      // Silently fail, will fetch from API
    }
    return null;
  }

  /// Cache timings to SharedPreferences
  Future<void> _cacheTimings(
    int chapterNumber,
    int reciterId,
    List<VerseTiming> timings,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix${chapterNumber}_$reciterId';
      
      final cache = ChapterTimingCache(
        chapterId: chapterNumber,
        reciterId: reciterId,
        timings: timings,
        cachedAt: DateTime.now(),
      );

      await prefs.setString(cacheKey, cache.toJsonString());
    } catch (e) {
      // Silently fail, caching is optional
    }
  }

  /// Clear cached timings for a specific chapter
  Future<void> clearChapterCache(int chapterNumber, int reciterId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix${chapterNumber}_$reciterId';
      await prefs.remove(cacheKey);
    } catch (e) {
      // Silently fail
    }
  }

  /// Clear all cached timings
  Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_cacheKeyPrefix)) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      // Silently fail
    }
  }

  /// Fetch list of available reciters
  Future<List<Map<String, dynamic>>> fetchReciters() async {
    try {
      final uri = Uri.parse('$baseUrl/chapter_recitations?language=en');
      final response = await http.get(uri).timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        final reciters = jsonData['reciters'] as List<dynamic>?;
        
        if (reciters != null) {
          return reciters
              .map((r) => r as Map<String, dynamic>)
              .toList();
        }
      }
    } catch (e) {
      // Silently fail
    }
    return [];
  }

  /// Check if timing data is available for a chapter and reciter
  Future<bool> hasTimingData(int chapterNumber, int reciterId) async {
    // Check cache first
    final cached = await _getCachedTimings(chapterNumber, reciterId);
    if (cached != null && cached.isNotEmpty) {
      return true;
    }

    // Try fetching (this will also cache it)
    final timings = await fetchChapterTimings(
      chapterNumber: chapterNumber,
      reciterId: reciterId,
      useCache: false,
    );

    return timings.isNotEmpty;
  }
}
