// Tam mushafı api.alquran.cloud üzerinden indirip assets/quran_offline.json üretir.
// Çalıştırma (proje kökü): dart run tool/build_quran_offline.dart
//
// Kaynak: Arapça quran-uthmani, Türkçe tr.diyanet (Al-Quran Cloud).

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:daily_dua_hadith/data/quran_surah_names_tr.dart';

const String _base = 'https://api.alquran.cloud/v1';

Future<void> main() async {
  final rows = <List<dynamic>>[];
  final client = http.Client();
  try {
    for (var s = 1; s <= 114; s++) {
      stdout.writeln('Sure $s / 114 …');
      final chunk = await _fetchSurah(client, s);
      rows.addAll(chunk);
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
  } finally {
    client.close();
  }

  final outFile = File('assets/quran_offline.json');
  await outFile.parent.create(recursive: true);
  await outFile.writeAsString(json.encode({'v': rows}));
  stdout.writeln('Bitti: ${rows.length} ayet → ${outFile.path}');
}

Future<List<List<dynamic>>> _fetchSurah(http.Client client, int surah) async {
  for (var attempt = 0; attempt < 5; attempt++) {
    try {
      final uri =
          Uri.parse('$_base/surah/$surah/editions/quran-uthmani,tr.diyanet');
      final res = await client.get(uri).timeout(const Duration(seconds: 90));
      if (res.statusCode != 200) {
        throw HttpException('HTTP ${res.statusCode}', uri: uri);
      }
      final root = json.decode(res.body) as Map<String, dynamic>;
      if (root['code'] != 200) {
        throw StateError(root['status']?.toString() ?? 'API');
      }
      final data = root['data'];
      if (data is! List<dynamic>) {
        throw StateError('Beklenmeyen data');
      }

      Map<String, dynamic>? editionById(String id) {
        for (final item in data) {
          if (item is! Map<String, dynamic>) continue;
          final edition = item['edition'];
          if (edition is Map<String, dynamic> &&
              edition['identifier'] == id) {
            return item;
          }
        }
        return null;
      }

      final arabic = editionById('quran-uthmani');
      final turkish = editionById('tr.diyanet');
      if (arabic == null || turkish == null) {
        throw StateError('Sürüm bulunamadı');
      }

      final arabicAyahs = arabic['ayahs'] as List<dynamic>?;
      final turkishAyahs = turkish['ayahs'] as List<dynamic>?;
      if (arabicAyahs == null ||
          turkishAyahs == null ||
          arabicAyahs.length != turkishAyahs.length) {
        throw StateError('Ayet sayısı uyuşmuyor');
      }

      final trName = kQuranTurkishSurahNames[surah] ?? 'Sure $surah';
      final footerName = trName.toUpperCase();

      final out = <List<dynamic>>[];
      for (var i = 0; i < arabicAyahs.length; i++) {
        final a = arabicAyahs[i] as Map<String, dynamic>;
        final t = turkishAyahs[i] as Map<String, dynamic>;
        final global = a['number'] as int? ?? 0;
        final inSurah = a['numberInSurah'] as int? ?? i + 1;
        final ar = (a['text'] as String? ?? '').replaceAll('\ufeff', '');
        final tr = (t['text'] as String? ?? '').trim();
        final footer = '$footerName SURESİ, $inSurah. AYET';
        out.add([surah, inSurah, global, ar, tr, footer]);
      }
      return out;
    } catch (e, st) {
      stderr.writeln('Sure $surah (deneme ${attempt + 1}): $e');
      if (attempt == 4) {
        stderr.writeln(st);
        throw StateError('Sure $surah yüklenemedi');
      }
      await Future<void>.delayed(Duration(seconds: 2 + attempt));
    }
  }
  throw StateError('Sure $surah');
}
