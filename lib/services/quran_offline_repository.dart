import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../data/quran_surah_names_tr.dart';
import '../models/local_widget_ayat.dart';
import '../models/quran_offline_verse.dart';
import '../models/surah_ayah_detail.dart';

/// Tam Kur’an metni (Uthmani + Diyanet meal) — `assets/quran_offline.json`, tamamen çevrimdışı.
/// Dosyayı oluşturmak için: `dart run tool/build_quran_offline.dart`
class QuranOfflineRepository {
  QuranOfflineRepository._();
  static final QuranOfflineRepository instance = QuranOfflineRepository._();

  List<QuranOfflineVerse>? _verses;
  Map<int, List<QuranOfflineVerse>>? _bySurah;
  Object? _loadError;

  bool get isReady => _verses != null && _verses!.isNotEmpty;

  Object? get loadError => _loadError;

  /// Mushaf sırasındaki toplam ayet sayısı (Fâtiha’dan başlar).
  int get totalAyahCount => _verses?.length ?? 0;

  Future<void> ensureLoaded() async {
    if (_verses != null) return;
    _loadError = null;
    try {
      final raw = await rootBundle.loadString('assets/quran_offline.json');
      final map = await compute(_decodeQuranJson, raw);
      final rows = map['v'] as List<dynamic>;
      _verses = rows.map((row) {
        final r = row as List<dynamic>;
        return QuranOfflineVerse(
          surah: r[0] as int,
          ayahInSurah: r[1] as int,
          globalAyah: r[2] as int,
          arabic: r[3] as String,
          turkish: r[4] as String,
          footer: r[5] as String,
        );
      }).toList();
      _bySurah = {};
      for (final v in _verses!) {
        _bySurah!.putIfAbsent(v.surah, () => []).add(v);
      }
    } catch (e, _) {
      _loadError = e;
      _verses = [];
      _bySurah = {};
    }
  }

  Future<LocalWidgetAyat?> pickForTodayAsWidgetAyat() async {
    await ensureLoaded();
    final list = _verses;
    if (list == null || list.isEmpty) return null;
    final dayKey = DateTime.now().toIso8601String().split('T').first;
    final hash = dayKey.codeUnits.fold(0, (a, b) => a + b);
    return _toWidgetAyat(list[hash % list.length]);
  }

  Future<LocalWidgetAyat?> pickRandomAsWidgetAyat() async {
    await ensureLoaded();
    final list = _verses;
    if (list == null || list.isEmpty) return null;
    final i = Random().nextInt(list.length);
    return _toWidgetAyat(list[i]);
  }

  /// [index] 0 tabanlı: 0 = Fâtiha 1. ayet.
  Future<LocalWidgetAyat?> widgetAyatAtListIndex(int index) async {
    await ensureLoaded();
    final list = _verses;
    if (list == null || list.isEmpty) return null;
    if (index < 0 || index >= list.length) return null;
    return _toWidgetAyat(list[index]);
  }

  /// Hatim liste indeksi → sure / sure içi ayet (Kur’an ekranına yönlendirme için).
  Future<QuranOfflineVerse?> verseAtListIndex(int index) async {
    await ensureLoaded();
    final list = _verses;
    if (list == null || list.isEmpty) return null;
    if (index < 0 || index >= list.length) return null;
    return list[index];
  }

  LocalWidgetAyat _toWidgetAyat(QuranOfflineVerse v) {
    return LocalWidgetAyat(
      surah: kQuranTurkishSurahNames[v.surah] ?? 'Sure ${v.surah}',
      footer: v.footer,
      ayah: v.ayahInSurah,
      arabic: v.arabic,
      turkish: v.turkish,
    );
  }

  Future<List<SurahAyahDetail>> getSurahAyahsAsDetails(int surahNumber) async {
    await ensureLoaded();
    final chunk = _bySurah?[surahNumber];
    if (chunk == null || chunk.isEmpty) return [];
    return chunk
        .map(
          (v) => SurahAyahDetail(
            globalAyahNumber: v.globalAyah,
            numberInSurah: v.ayahInSurah,
            arabicText: v.arabic,
            turkishText: v.turkish,
            audioCandidateUrls: const [],
          ),
        )
        .toList();
  }
}

@pragma('vm:entry-point')
Map<String, dynamic> _decodeQuranJson(String raw) {
  return json.decode(raw) as Map<String, dynamic>;
}
