import 'dart:convert';

/// Represents timing information for a single word
class WordTiming {
  final int wordIndex; // Index of word in the verse (0-based)
  final int startMs; // Start time in milliseconds
  final int endMs; // End time in milliseconds

  WordTiming({
    required this.wordIndex,
    required this.startMs,
    required this.endMs,
  });

  /// Factory constructor from Quran Foundation API segment array [word_index, start_ms, end_ms]
  factory WordTiming.fromSegment(List<dynamic> segment) {
    // API returns either [word_index, start_ms, end_ms] or single value segments
    if (segment.isEmpty) {
      throw ArgumentError('Segment array is empty');
    }
    
    // Some segments might be single values (like verse markers) - skip them
    if (segment.length < 3) {
      throw ArgumentError('Segment must have at least 3 elements: [word_index, start_ms, end_ms]');
    }
    
    return WordTiming(
      wordIndex: (segment[0] as num).toInt(),
      startMs: (segment[1] as num).toInt(),
      endMs: (segment[2] as num).toInt(),
    );
  }

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'wordIndex': wordIndex,
      'startMs': startMs,
      'endMs': endMs,
    };
  }

  /// Factory constructor from JSON
  factory WordTiming.fromJson(Map<String, dynamic> json) {
    return WordTiming(
      wordIndex: json['wordIndex'] as int,
      startMs: json['startMs'] as int,
      endMs: json['endMs'] as int,
    );
  }

  @override
  String toString() {
    return 'WordTiming(word: $wordIndex, ${startMs}ms-${endMs}ms)';
  }
}

/// Represents timing information for a complete verse
class VerseTiming {
  final String verseKey; // Format: "1:1" (surah:verse)
  final int timestampFrom; // Start time in milliseconds
  final int timestampTo; // End time in milliseconds
  final List<WordTiming> segments; // Word-level timing data

  VerseTiming({
    required this.verseKey,
    required this.timestampFrom,
    required this.timestampTo,
    required this.segments,
  });

  /// Factory constructor from Quran Foundation API response
  factory VerseTiming.fromJson(Map<String, dynamic> json) {
    final segmentsList = json['segments'] as List<dynamic>? ?? [];
    final segments = <WordTiming>[];
    
    // Parse segments, skip invalid ones
    for (final seg in segmentsList) {
      try {
        if (seg is List<dynamic> && seg.length >= 3) {
          segments.add(WordTiming.fromSegment(seg));
        }
      } catch (e) {
        // Skip invalid segments silently
      }
    }

    return VerseTiming(
      verseKey: json['verse_key'] as String? ?? '',
      timestampFrom: json['timestamp_from'] as int? ?? 0,
      timestampTo: json['timestamp_to'] as int? ?? 0,
      segments: segments,
    );
  }

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'verse_key': verseKey,
      'timestamp_from': timestampFrom,
      'timestamp_to': timestampTo,
      'segments': segments.map((s) => s.toJson()).toList(),
    };
  }

  /// Factory constructor from cached JSON
  factory VerseTiming.fromCachedJson(Map<String, dynamic> json) {
    final segmentsList = json['segments'] as List<dynamic>? ?? [];
    final segments = segmentsList
        .map((seg) => WordTiming.fromJson(seg as Map<String, dynamic>))
        .toList();

    return VerseTiming(
      verseKey: json['verse_key'] as String? ?? '',
      timestampFrom: json['timestamp_from'] as int? ?? 0,
      timestampTo: json['timestamp_to'] as int? ?? 0,
      segments: segments,
    );
  }

  /// Get verse number from verse_key (e.g., "1:1" -> 1)
  int get verseNumber {
    final parts = verseKey.split(':');
    return parts.length == 2 ? int.tryParse(parts[1]) ?? 0 : 0;
  }

  /// Get surah number from verse_key (e.g., "1:1" -> 1)
  int get surahNumber {
    final parts = verseKey.split(':');
    return parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
  }

  @override
  String toString() {
    return 'VerseTiming($verseKey, ${timestampFrom}ms-${timestampTo}ms, ${segments.length} words)';
  }
}

/// Helper class for caching chapter timings
class ChapterTimingCache {
  final int chapterId;
  final int reciterId;
  final List<VerseTiming> timings;
  final DateTime cachedAt;

  ChapterTimingCache({
    required this.chapterId,
    required this.reciterId,
    required this.timings,
    required this.cachedAt,
  });

  /// Convert to JSON string for SharedPreferences
  String toJsonString() {
    final map = {
      'chapterId': chapterId,
      'reciterId': reciterId,
      'cachedAt': cachedAt.toIso8601String(),
      'timings': timings.map((t) => t.toJson()).toList(),
    };
    return jsonEncode(map);
  }

  /// Factory constructor from JSON string
  factory ChapterTimingCache.fromJsonString(String jsonString) {
    final map = jsonDecode(jsonString) as Map<String, dynamic>;
    final timingsList = map['timings'] as List<dynamic>;
    final timings = timingsList
        .map((t) => VerseTiming.fromCachedJson(t as Map<String, dynamic>))
        .toList();

    return ChapterTimingCache(
      chapterId: map['chapterId'] as int,
      reciterId: map['reciterId'] as int,
      timings: timings,
      cachedAt: DateTime.parse(map['cachedAt'] as String),
    );
  }

  /// Check if cache is still valid (e.g., less than 7 days old)
  bool isValid({Duration maxAge = const Duration(days: 7)}) {
    return DateTime.now().difference(cachedAt) < maxAge;
  }
}
