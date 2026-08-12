import 'package:shared_preferences/shared_preferences.dart';

import '../models/esmaul_husna_progress.dart';

class EsmaulHusnaService {
  static const _favoritesKey = 'esmaul_husna_favorites_v1';
  static const _memorizedKey = 'esmaul_husna_memorized_v1';

  Future<EsmaulHusnaProgress> loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    return EsmaulHusnaProgress(
      favorites: _decode(prefs.getStringList(_favoritesKey)),
      memorized: _decode(prefs.getStringList(_memorizedKey)),
    );
  }

  Future<EsmaulHusnaProgress> toggleFavorite(int number) async {
    _checkNumber(number);
    final prefs = await SharedPreferences.getInstance();
    final favorites = _decode(prefs.getStringList(_favoritesKey));
    favorites.contains(number)
        ? favorites.remove(number)
        : favorites.add(number);
    await prefs.setStringList(_favoritesKey, _encode(favorites));
    return loadProgress();
  }

  Future<EsmaulHusnaProgress> toggleMemorized(int number) async {
    _checkNumber(number);
    final prefs = await SharedPreferences.getInstance();
    final memorized = _decode(prefs.getStringList(_memorizedKey));
    memorized.contains(number)
        ? memorized.remove(number)
        : memorized.add(number);
    await prefs.setStringList(_memorizedKey, _encode(memorized));
    return loadProgress();
  }

  Set<int> _decode(List<String>? values) => (values ?? const <String>[])
      .map(int.tryParse)
      .whereType<int>()
      .where((value) => value >= 1 && value <= 99)
      .toSet();

  List<String> _encode(Set<int> values) {
    final sorted = values.toList()..sort();
    return sorted.map((value) => '$value').toList();
  }

  void _checkNumber(int number) {
    if (number < 1 || number > 99) {
      throw RangeError.range(number, 1, 99, 'number');
    }
  }
}
