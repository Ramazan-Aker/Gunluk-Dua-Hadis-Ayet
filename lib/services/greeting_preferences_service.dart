import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/greeting_message.dart';

/// Stores the user's message library and share-card signature locally.
class GreetingPreferencesService {
  static const _favoritesKey = 'greeting_favorite_messages_v1';
  static const _recentsKey = 'greeting_recent_messages_v1';
  static const _signatureKey = 'greeting_signature_v1';
  static const _recentLimit = 12;

  Future<List<GreetingMessage>> loadFavorites() => _loadMessages(_favoritesKey);

  Future<List<GreetingMessage>> loadRecents() => _loadMessages(_recentsKey);

  Future<String> loadSignature() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_signatureKey) ?? '';
  }

  Future<void> saveSignature(String signature) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_signatureKey, signature.trim());
  }

  Future<List<GreetingMessage>> toggleFavorite(
    GreetingMessage message,
  ) async {
    final favorites = await loadFavorites();
    final existingIndex = favorites.indexWhere(
      (item) => _messageKey(item) == _messageKey(message),
    );
    if (existingIndex >= 0) {
      favorites.removeAt(existingIndex);
    } else {
      favorites.insert(0, message);
    }
    await _saveMessages(_favoritesKey, favorites);
    return favorites;
  }

  Future<List<GreetingMessage>> addRecent(GreetingMessage message) async {
    final recents = await loadRecents();
    recents.removeWhere((item) => _messageKey(item) == _messageKey(message));
    recents.insert(0, message);
    if (recents.length > _recentLimit) {
      recents.removeRange(_recentLimit, recents.length);
    }
    await _saveMessages(_recentsKey, recents);
    return recents;
  }

  Future<List<GreetingMessage>> _loadMessages(String key) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(key);
    if (encoded == null || encoded.isEmpty) return [];

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .map(
            (entry) => GreetingMessage.fromJson(
              entry,
              entry['category'] as String? ?? 'cuma',
            ),
          )
          .where((message) => message.text.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveMessages(
    String key,
    List<GreetingMessage> messages,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      key,
      jsonEncode(messages.map((message) => message.toJson()).toList()),
    );
  }

  String _messageKey(GreetingMessage message) {
    final identity =
        message.id.trim().isEmpty ? message.text.trim() : message.id;
    return '${message.category}::$identity';
  }
}
