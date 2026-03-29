import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/surah_ayah_detail.dart';

/// Arapça (Uthmani) + Türkçe (Diyanet) ayet metni. Ses Quran.com tek parça API ile ayrı yüklenir.
class AlquranCloudSurahService {
  static const String baseUrl = 'https://api.alquran.cloud/v1';
  static const String editions = 'quran-uthmani,tr.diyanet';
  static const Duration timeout = Duration(seconds: 20);

  Future<List<SurahAyahDetail>> fetchSurahAyahs(int surahNumber) async {
    if (surahNumber < 1 || surahNumber > 114) {
      throw ArgumentError('Invalid surah number: $surahNumber');
    }

    final uri = Uri.parse('$baseUrl/surah/$surahNumber/editions/$editions');
    final response = await http.get(uri).timeout(timeout);

    if (response.statusCode != 200) {
      throw AlquranCloudException(
        'Sunucu yanıt vermedi (${response.statusCode}).',
      );
    }

    final root = json.decode(response.body) as Map<String, dynamic>;
    final code = root['code'];
    if (code != 200) {
      throw AlquranCloudException(
        root['status']?.toString() ?? 'Bilinmeyen API hatası',
      );
    }

    final data = root['data'];
    if (data is! List) {
      throw AlquranCloudException('Beklenmeyen veri formatı.');
    }

    Map<String, dynamic>? byId(String id) {
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

    final arabic = byId('quran-uthmani');
    final turkish = byId('tr.diyanet');

    if (arabic == null || turkish == null) {
      throw AlquranCloudException(
        'Arapça veya Türkçe metin yüklenemedi.',
      );
    }

    final arabicAyahs = arabic['ayahs'] as List<dynamic>?;
    final turkishAyahs = turkish['ayahs'] as List<dynamic>?;

    if (arabicAyahs == null ||
        turkishAyahs == null ||
        arabicAyahs.length != turkishAyahs.length) {
      throw AlquranCloudException('Ayet verileri eşleşmiyor.');
    }

    final List<SurahAyahDetail> out = [];
    for (var i = 0; i < arabicAyahs.length; i++) {
      final a = arabicAyahs[i] as Map<String, dynamic>;
      final t = turkishAyahs[i] as Map<String, dynamic>;

      final arabicText = (a['text'] as String? ?? '').replaceAll('\ufeff', '');
      final turkishText = (t['text'] as String? ?? '').trim();

      out.add(
        SurahAyahDetail(
          globalAyahNumber: a['number'] as int? ?? 0,
          numberInSurah: a['numberInSurah'] as int? ?? i + 1,
          arabicText: arabicText,
          turkishText: turkishText,
          audioCandidateUrls: const [],
        ),
      );
    }

    return out;
  }
}

class AlquranCloudException implements Exception {
  final String message;
  AlquranCloudException(this.message);

  @override
  String toString() => message;
}
