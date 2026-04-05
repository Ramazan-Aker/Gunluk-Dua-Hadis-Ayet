import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

/// Pixabay API - Ücretsiz İslami görseller
/// API Key: https://pixabay.com/api/docs/ adresinden ücretsiz alınır
/// CC0 lisans - attribution zorunlu değil
class PixabayImageService {
  static const String _baseUrl = 'https://pixabay.com/api';
  static const Duration _timeout = Duration(seconds: 8);

  /// Pixabay API anahtarı (https://pixabay.com/api/docs/)
  static const String apiKey = '54839412-ddd836a63ab0c1907f43b7b1f';

  static final Random _random = Random();

  /// Mesaj bazlı önbellek: "categoryId_messageId" -> URL (her mesajda farklı görsel)
  static final Map<String, String> _urlCache = {};

  /// Dini/İslami arama terimleri - İngilizce + Arapça (مسجد, كعبة, قرآن vb.)
  static const Map<String, List<String>> _searchTerms = {
    'cuma': ['مسجد', 'mosque', 'islamic mosque', 'minaret', 'جامع'],
    'mevlid': ['مسجد', 'ramadan mosque', 'mosque night', 'مولد', 'islamic'],
    'regaib': ['مسجد', 'mosque night', 'islamic', 'منارة', 'ramadan'],
    'mirac': ['مسجد', 'معراج', 'mosque night', 'islamic mosque', 'minaret'],
    'berat': ['مسجد', 'براءة', 'mosque night', 'islamic', 'قمر'],
    'kadir': ['قدر', 'ramadan', 'مسجد', 'kaaba', 'كعبة'],
    'ramazan_bayrami': ['عيد', 'eid', 'مسجد', 'ramadan', 'عید فطر'],
    'kurban_bayrami': ['عيد', 'كعبة', 'kaaba', 'مسجد', 'عید اضحی'],
    'günlük_dua': ['قرآن', 'quran', 'مسجد', 'prayer rug', 'سجادة'],
    'tebrikler': ['celebration', 'flowers', 'gift', 'هدية', 'احتفال'],
    'teselli': ['comfort', 'peace', 'nature', 'سلام', 'طبيعة'],
    'hayirli_olsun': ['blessing', 'home', 'new beginning', 'بركة'],
    'dua_isteme': ['prayer', 'hands praying', 'دعاء', 'صلاة'],
  };

  /// İslami görsel URL'si getir - her mesaj için farklı görsel
  /// [categoryId] - Mesaj kategorisi (cuma, mevlid, ramazan_bayrami vb.)
  /// [messageId] - Mesaj ID'si (her mesajda farklı görsel için). Boşsa rastgele.
  Future<String?> fetchRandomImage(String categoryId, {String? messageId}) async {
    if (apiKey.isEmpty) return null;

    final cacheKey = messageId != null && messageId.isNotEmpty
        ? '${categoryId}_$messageId'
        : '${categoryId}_${DateTime.now().millisecondsSinceEpoch}';

    if (_urlCache.containsKey(cacheKey)) {
      return _urlCache[cacheKey];
    }

    final terms = _searchTerms[categoryId] ?? ['مسجد', 'islamic mosque', 'mosque'];
    var query = terms[_random.nextInt(terms.length)];

    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        final uri = Uri.parse(_baseUrl).replace(queryParameters: {
          'key': apiKey,
          'q': query,
          'image_type': 'photo',
          'safesearch': 'true',
          'per_page': '30',
          'category': 'religion',
          'page': '${_random.nextInt(5) + 1}',
        });

        final response = await http.get(uri).timeout(_timeout);

        if (response.statusCode != 200) return null;

        final data = json.decode(response.body);
        final hits = data['hits'] as List? ?? [];

        if (hits.isNotEmpty) {
          final hit = hits[_random.nextInt(hits.length)] as Map<String, dynamic>;
          final url = hit['largeImageURL'] as String? ??
              hit['webformatURL'] as String? ??
              hit['previewURL'] as String?;

          if (url != null && messageId != null && messageId.isNotEmpty) {
            _urlCache[cacheKey] = url;
          }
          return url;
        }
        query = attempt == 0 ? 'mosque' : 'islamic';
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Kategori seçildiğinde ilk görseli önceden yükle (ping azaltır)
  void prefetchForCategory(String categoryId) {
    if (apiKey.isEmpty) return;
    fetchRandomImage(categoryId, messageId: 'prefetch');
  }

  /// Genel İslami görsel (kategori belirtilmeden)
  Future<String?> fetchIslamicImage() async {
    return fetchRandomImage('cuma');
  }
}
