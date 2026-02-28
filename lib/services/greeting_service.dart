import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/greeting_message.dart';

/// Service for loading Cuma, Kandil, and Bayram greeting messages
class GreetingService {
  static final GreetingService _instance = GreetingService._internal();
  factory GreetingService() => _instance;
  GreetingService._internal();

  Map<String, List<GreetingMessage>> _messages = {};

  /// Load all greeting messages from JSON
  Future<void> loadMessages() async {
    if (_messages.isNotEmpty) return;

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
      print('✅ Loaded greeting messages for ${_messages.length} categories');
    } catch (e) {
      print('❌ Error loading greeting messages: $e');
      _messages = {};
    }
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
    ];
  }

  /// Get subcategory IDs for main groups
  List<String> getKandilIds() => GreetingCategoryInfo.kandilIds;
  List<String> getBayramIds() => GreetingCategoryInfo.bayramIds;
}
