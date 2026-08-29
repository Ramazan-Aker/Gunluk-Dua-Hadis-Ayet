import 'package:shared_preferences/shared_preferences.dart';

class ReadyMessagePreferencesService {
  static const _favoriteIdsKey = 'ready_message_favorite_ids_v1';

  Future<Set<String>> loadFavoriteIds() async {
    final preferences = await SharedPreferences.getInstance();
    return (preferences.getStringList(_favoriteIdsKey) ?? const []).toSet();
  }

  Future<Set<String>> toggleFavorite(String designId) async {
    final preferences = await SharedPreferences.getInstance();
    final favoriteIds =
        (preferences.getStringList(_favoriteIdsKey) ?? const []).toSet();
    if (!favoriteIds.add(designId)) {
      favoriteIds.remove(designId);
    }
    final orderedIds = favoriteIds.toList()..sort();
    await preferences.setStringList(_favoriteIdsKey, orderedIds);
    return favoriteIds;
  }
}
