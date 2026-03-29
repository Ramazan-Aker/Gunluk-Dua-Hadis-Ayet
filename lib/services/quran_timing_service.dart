import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chapter_recitation.dart';
import '../models/verse_timing.dart';

/// Quran.com API v4 - chapter recitations (audio + timestamps).
class QuranTimingService {
  static const String baseUrl = 'https://api.quran.com/api/v4';
  static const Duration timeoutDuration = Duration(seconds: 20);

  static const int haniArRifaiReciterId = 7;

  static const String _cacheKeyPrefix = 'quran_timing_';

  /// Maps app UI reciter id ([QuranAudioService]) to Quran.com `chapter_recitations` id.
  static int quranComRecitationIdForAppReciter(int appReciterId) {
    switch (appReciterId) {
      case 1:
        return 7;
      case 2:
        return 4;
      case 3:
      case 4:
        return 5;
      case 5:
      case 7:
        return 5;
      default:
        return 5;
    }
  }

  Future<ChapterRecitationResult?> fetchChapterRecitationWithAudio({
    required int chapterNumber,
    required int appReciterId,
    bool useCache = true,
  }) async {
    final qcId = quranComRecitationIdForAppReciter(appReciterId);

    if (useCache) {
      final cached = await _getCachedRecitation(chapterNumber, qcId);
      if (cached != null && cached.hasSyncData) {
        return cached;
      }
    }

    try {
      final uri = Uri.parse(
        '$baseUrl/chapter_recitations/$qcId/$chapterNumber?segments=true',
      );
      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
        'Cache-Control': 'max-age=86400',
      }).timeout(timeoutDuration);

      if (response.statusCode != 200) return null;

      final jsonData = json.decode(response.body) as Map<String, dynamic>;
      final audioFile = jsonData['audio_file'] as Map<String, dynamic>?;
      if (audioFile == null) return null;

      final audioUrl = audioFile['audio_url'] as String?;
      final timestamps = audioFile['timestamps'] as List<dynamic>?;
      if (timestamps == null || timestamps.isEmpty) {
        return ChapterRecitationResult(
          audioUrl: audioUrl,
          timings: <VerseTiming>[],
          quranComReciterId: qcId,
        );
      }

      final timings = timestamps
          .map((t) => VerseTiming.fromJson(t as Map<String, dynamic>))
          .toList();

      await _cacheTimings(chapterNumber, qcId, timings, audioUrl: audioUrl);

      return ChapterRecitationResult(
        audioUrl: audioUrl,
        timings: timings,
        quranComReciterId: qcId,
      );
    } catch (e) {
      return null;
    }
  }

  Future<List<VerseTiming>> fetchChapterTimings({
    required int chapterNumber,
    int? reciterId,
    bool useCache = true,
  }) async {
    final appId = reciterId ?? haniArRifaiReciterId;
    final r = await fetchChapterRecitationWithAudio(
      chapterNumber: chapterNumber,
      appReciterId: appId,
      useCache: useCache,
    );
    return r?.timings ?? [];
  }

  Future<ChapterRecitationResult?> _getCachedRecitation(
    int chapterNumber,
    int qcReciterId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix${chapterNumber}_$qcReciterId';
      final cachedJson = prefs.getString(cacheKey);
      if (cachedJson == null) return null;

      final cache = ChapterTimingCache.fromJsonString(cachedJson);
      if (!cache.isValid()) {
        await prefs.remove(cacheKey);
        return null;
      }

      return ChapterRecitationResult(
        audioUrl: cache.audioUrl,
        timings: cache.timings,
        quranComReciterId: qcReciterId,
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> _cacheTimings(
    int chapterNumber,
    int reciterId,
    List<VerseTiming> timings, {
    String? audioUrl,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix${chapterNumber}_$reciterId';
      final cache = ChapterTimingCache(
        chapterId: chapterNumber,
        reciterId: reciterId,
        timings: timings,
        cachedAt: DateTime.now(),
        audioUrl: audioUrl,
      );
      await prefs.setString(cacheKey, cache.toJsonString());
    } catch (e) {}
  }

  Future<void> clearChapterCache(int chapterNumber, int reciterId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix${chapterNumber}_$reciterId';
      await prefs.remove(cacheKey);
    } catch (e) {}
  }

  Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        if (key.startsWith(_cacheKeyPrefix)) {
          await prefs.remove(key);
        }
      }
    } catch (e) {}
  }

  Future<List<Map<String, dynamic>>> fetchReciters() async {
    try {
      final uri = Uri.parse('$baseUrl/chapter_recitations?language=en');
      final response = await http.get(uri).timeout(timeoutDuration);
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        final reciters = jsonData['reciters'] as List<dynamic>?;
        if (reciters != null) {
          return reciters.map((r) => r as Map<String, dynamic>).toList();
        }
      }
    } catch (e) {}
    return [];
  }

  Future<bool> hasTimingData(int chapterNumber, int reciterId) async {
    final r = await fetchChapterRecitationWithAudio(
      chapterNumber: chapterNumber,
      appReciterId: reciterId,
      useCache: true,
    );
    return r != null && r.timings.isNotEmpty;
  }
}
