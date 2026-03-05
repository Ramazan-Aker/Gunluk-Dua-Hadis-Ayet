import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/greeting_message.dart';

/// Dua & Dhikr API - Sünnete uygun dua ve zikir metinleri
/// Kaynak: https://dua-dhikr.vercel.app (MIT lisans)
/// Desteklenen diller: id (Endonezce), en (İngilizce)
class DuaDhikrApiService {
  static const String _baseUrl = 'https://dua-dhikr.vercel.app';
  static const Duration _timeout = Duration(seconds: 10);

  /// Kategorilere göre dua/dhikr listesi getir
  /// [language] - 'en' veya 'id'
  Future<List<GreetingMessage>> fetchDuasFromCategory(String slug,
      {String language = 'en'}) async {
    try {
      final uri = Uri.parse('$_baseUrl/categories/$slug');
      final response = await http.get(
        uri,
        headers: {'Accept-Language': language},
      ).timeout(_timeout);

      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      final list = data is List ? data : (data['data'] as List? ?? data['items'] as List? ?? []);

      return list.asMap().entries.map((e) {
        final item = e.value as Map<String, dynamic>;
        final id = e.key;
        final title = item['title'] as String? ?? 'Dua';
        final translation = item['translation'] as String? ?? '';
        final arabic = item['arabic'] as String? ?? '';
        final text = translation.isNotEmpty
            ? translation
            : (item['latin'] as String? ?? arabic);

        return GreetingMessage(
          id: 'dua_${slug}_$id',
          category: 'günlük_dua',
          title: title,
          text: text.isNotEmpty ? text : title,
        );
      }).where((m) => m.text.isNotEmpty).toList();
    } catch (e) {
      return [];
    }
  }

  /// Tüm kategorileri getir
  Future<List<String>> fetchCategories() async {
    try {
      final uri = Uri.parse('$_baseUrl/categories');
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode != 200) return [];

      final data = json.decode(response.body);
      final list = data is List ? data : (data['data'] as List? ?? []);

      return list.map((e) {
        if (e is Map) return e['slug'] as String? ?? e['id'] as String? ?? '';
        return e.toString();
      }).where((s) => s.isNotEmpty).toList();
    } catch (e) {
      return ['daily-dua', 'morning-dhikr', 'evening-dhikr'];
    }
  }
}
