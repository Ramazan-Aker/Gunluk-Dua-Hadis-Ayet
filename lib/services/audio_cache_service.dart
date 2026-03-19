import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Service for caching Quran audio files locally
class AudioCacheService {
  static const String _cacheKeyPrefix = 'quran_audio_cached_';
  static const int maxCacheSizeMB = 500; // Maximum 500MB cache
  
  /// Get cache directory for audio files
  Future<Directory> _getCacheDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/quran_audio_cache');
    
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    
    return cacheDir;
  }

  /// Generate cache file path for a surah
  String _getCacheFileName(int surahNumber, int reciterId) {
    return 'surah_${surahNumber}_reciter_$reciterId.mp3';
  }

  /// Check if audio is cached
  Future<bool> isCached(int surahNumber, int reciterId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_cacheKeyPrefix${surahNumber}_$reciterId';
      return prefs.getBool(key) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Get cached audio file path
  Future<String?> getCachedAudioPath(int surahNumber, int reciterId) async {
    try {
      if (!await isCached(surahNumber, reciterId)) {
        return null;
      }

      final cacheDir = await _getCacheDir();
      final fileName = _getCacheFileName(surahNumber, reciterId);
      final file = File('${cacheDir.path}/$fileName');

      if (await file.exists()) {
        return file.path;
      } else {
        // File was deleted, update cache status
        await _markAsNotCached(surahNumber, reciterId);
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  /// Download and cache audio file
  Future<String?> downloadAndCache({
    required String url,
    required int surahNumber,
    required int reciterId,
    Function(double progress)? onProgress,
  }) async {
    try {
      final cacheDir = await _getCacheDir();
      final fileName = _getCacheFileName(surahNumber, reciterId);
      final filePath = '${cacheDir.path}/$fileName';
      final file = File(filePath);

      // Check cache size before downloading
      final currentSize = await _getCacheSizeInMB();
      if (currentSize > maxCacheSizeMB) {
        // Clear old cache files
        await _clearOldCache();
      }

      // Download file with progress
      final request = await http.Client().send(http.Request('GET', Uri.parse(url)));
      final contentLength = request.contentLength ?? 0;
      var downloadedBytes = 0;

      final bytes = <int>[];
      await for (final chunk in request.stream) {
        bytes.addAll(chunk);
        downloadedBytes += chunk.length;
        
        if (contentLength > 0 && onProgress != null) {
          final progress = downloadedBytes / contentLength;
          onProgress(progress);
        }
      }

      // Write to file
      await file.writeAsBytes(bytes);

      // Mark as cached
      await _markAsCached(surahNumber, reciterId);

      return filePath;
    } catch (e) {
      return null;
    }
  }

  /// Mark audio as cached
  Future<void> _markAsCached(int surahNumber, int reciterId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_cacheKeyPrefix${surahNumber}_$reciterId';
      await prefs.setBool(key, true);
      
      // Store timestamp for LRU cache management
      final timestampKey = '${key}_timestamp';
      await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// Mark audio as not cached
  Future<void> _markAsNotCached(int surahNumber, int reciterId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_cacheKeyPrefix${surahNumber}_$reciterId';
      await prefs.remove(key);
      await prefs.remove('${key}_timestamp');
    } catch (_) {}
  }

  /// Get total cache size in MB
  Future<double> _getCacheSizeInMB() async {
    try {
      final cacheDir = await _getCacheDir();
      var totalSize = 0;

      await for (final entity in cacheDir.list()) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }

      return totalSize / (1024 * 1024); // Convert to MB
    } catch (_) {
      return 0;
    }
  }

  /// Clear old cached files (LRU - Least Recently Used)
  Future<void> _clearOldCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheDir = await _getCacheDir();
      
      // Get all cached files with timestamps
      final cachedFiles = <String, int>{};
      final keys = prefs.getKeys().where((k) => k.startsWith(_cacheKeyPrefix) && k.endsWith('_timestamp'));
      
      for (final key in keys) {
        final timestamp = prefs.getInt(key) ?? 0;
        final baseKey = key.replaceAll('_timestamp', '');
        cachedFiles[baseKey] = timestamp;
      }

      // Sort by timestamp (oldest first)
      final sortedKeys = cachedFiles.keys.toList()
        ..sort((a, b) => cachedFiles[a]!.compareTo(cachedFiles[b]!));

      // Delete oldest 30% of files
      final deleteCount = (sortedKeys.length * 0.3).ceil();
      for (var i = 0; i < deleteCount && i < sortedKeys.length; i++) {
        final key = sortedKeys[i];
        final parts = key.replaceAll(_cacheKeyPrefix, '').split('_');
        
        if (parts.length >= 2) {
          final surahNumber = int.tryParse(parts[0]);
          final reciterId = int.tryParse(parts[1]);
          
          if (surahNumber != null && reciterId != null) {
            final fileName = _getCacheFileName(surahNumber, reciterId);
            final file = File('${cacheDir.path}/$fileName');
            
            if (await file.exists()) {
              await file.delete();
            }
            
            await _markAsNotCached(surahNumber, reciterId);
          }
        }
      }
    } catch (_) {}
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    try {
      final cacheDir = await _getCacheDir();
      
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }

      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_cacheKeyPrefix));
      
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final sizeMB = await _getCacheSizeInMB();
      final prefs = await SharedPreferences.getInstance();
      final cachedCount = prefs.getKeys()
          .where((k) => k.startsWith(_cacheKeyPrefix) && !k.endsWith('_timestamp'))
          .length;

      return {
        'sizeMB': sizeMB,
        'cachedCount': cachedCount,
        'maxSizeMB': maxCacheSizeMB,
      };
    } catch (_) {
      return {
        'sizeMB': 0.0,
        'cachedCount': 0,
        'maxSizeMB': maxCacheSizeMB,
      };
    }
  }
}
