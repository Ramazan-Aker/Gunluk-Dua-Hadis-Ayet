import 'package:shared_preferences/shared_preferences.dart';

class QuranProgressService {
  static const _completedJuzKey = 'quran_completed_juz_v1';

  Future<Set<int>> completedJuz() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_completedJuzKey) ?? const <String>[])
        .map(int.tryParse)
        .whereType<int>()
        .where((number) => number >= 1 && number <= 30)
        .toSet();
  }

  Future<Set<int>> setJuzCompleted(int number, bool completed) async {
    final values = await completedJuz();
    completed ? values.add(number) : values.remove(number);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _completedJuzKey,
      values.map((value) => value.toString()).toList()..sort(),
    );
    return values;
  }
}
