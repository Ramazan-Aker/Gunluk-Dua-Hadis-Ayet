import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/greeting_message.dart';
import 'dua_dhikr_api_service.dart';
import 'pixabay_image_service.dart';

/// Service for loading Cuma, Kandil, and Bayram greeting messages
/// Yerel JSON + Dua-Dhikr API + Pixabay görseller
class GreetingService {
  static final GreetingService _instance = GreetingService._internal();
  factory GreetingService() => _instance;
  GreetingService._internal();

  final DuaDhikrApiService _duaApi = DuaDhikrApiService();
  final PixabayImageService _pixabay = PixabayImageService();

  Map<String, List<GreetingMessage>> _messages = {};
  bool _apiMessagesLoaded = false;

  /// Load all greeting messages (local JSON + API)
  Future<void> loadMessages() async {
    if (_messages.isNotEmpty && _apiMessagesLoaded) return;

    try {
      final String jsonString =
          await rootBundle.loadString('assets/greeting_messages.json');
      final Map<String, dynamic> data = json.decode(jsonString);

      _messages = {};
      for (final entry in data.entries) {
        final category = entry.key;
        final list = entry.value;
        if (list is! List) continue;
        _messages[category] = [
          for (final e in list)
            if (e is Map)
              GreetingMessage.fromJson(
                  Map<String, dynamic>.from(e), category),
        ];
      }

      await _loadApiMessages();
    } catch (e) {
      _messages = {};
    }
  }

  /// Günlük dua/zikir: Önce JSON'dan (Türkçe) yükle; yoksa API'den dene (İngilizce)
  Future<void> _loadApiMessages() async {
    if (_apiMessagesLoaded) return;
    // JSON'da günlük_dua varsa (Türkçe mesajlar) API'yi atla - anlamlı Türkçe içerik öncelikli
    if (_messages.containsKey('günlük_dua') && _messages['günlük_dua']!.isNotEmpty) {
      _apiMessagesLoaded = true;
      return;
    }
    try {
      final duas = await _duaApi.fetchDuasFromCategory('daily-dua');
      if (duas.isNotEmpty) {
        _messages['günlük_dua'] = duas;
        _apiMessagesLoaded = true;
      }
    } catch (e) {}
  }

  /// Mesaj için görsel URL getir - her mesajda farklı görsel (Pixabay)
  /// [messageId] - Mesaj ID'si (boşsa özel mesaj, her seferinde yeni görsel)
  Future<String?> fetchImageForMessage(String categoryId, {String? messageId}) async {
    return _pixabay.fetchRandomImage(categoryId, messageId: messageId);
  }

  /// Görseli önceden yükle - mesaj seçim ekranına girildiğinde ping azaltır
  void prefetchImageForCategory(String categoryId) {
    _pixabay.prefetchForCategory(categoryId);
  }

  /// Get messages for a category
  List<GreetingMessage> getMessagesForCategory(String categoryId) {
    return _messages[categoryId] ?? [];
  }

  /// Get all available category IDs
  List<String> getAllCategoryIds() {
    return [
      ...GreetingCategoryInfo.cumaIds,
      ...GreetingCategoryInfo.kandilIds,
      ...GreetingCategoryInfo.bayramIds,
      if (_messages.containsKey('günlük_dua')) ...GreetingCategoryInfo.apiCategoryIds,
    ];
  }

  /// Get subcategory IDs for main groups
  List<String> getKandilIds() => GreetingCategoryInfo.kandilIds;
  List<String> getBayramIds() => GreetingCategoryInfo.bayramIds;
}
