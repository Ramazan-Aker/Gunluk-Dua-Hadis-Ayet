import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class QuranProgressService {
  static const _completedJuzKey = 'quran_completed_juz_v1';
  static const _completionHistoryKey = 'quran_completed_juz_dates_v1';

  Future<Set<int>> completedJuz() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_completedJuzKey) ?? const <String>[])
        .map(int.tryParse)
        .whereType<int>()
        .where((number) => number >= 1 && number <= 30)
        .toSet();
  }

  Future<Map<int, DateTime>> completionDates() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_completionHistoryKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final result = <int, DateTime>{};
      for (final entry in decoded.entries) {
        final number = int.tryParse(entry.key);
        final date = DateTime.tryParse(entry.value as String? ?? '');
        if (number == null || number < 1 || number > 30 || date == null) {
          continue;
        }
        result[number] = DateTime(date.year, date.month, date.day);
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<Set<int>> setJuzCompleted(
    int number,
    bool completed, {
    DateTime? now,
  }) async {
    if (number < 1 || number > 30) {
      throw ArgumentError.value(number, 'number', 'Cüz numarası 1-30 olmalı');
    }
    final values = await completedJuz();
    final dates = await completionDates();
    completed ? values.add(number) : values.remove(number);
    if (completed) {
      final date = now ?? DateTime.now();
      dates.putIfAbsent(
          number, () => DateTime(date.year, date.month, date.day));
    } else {
      dates.remove(number);
    }
    final prefs = await SharedPreferences.getInstance();
    final sorted = values.toList()..sort();
    await prefs.setStringList(
      _completedJuzKey,
      sorted.map((value) => value.toString()).toList(),
    );
    await prefs.setString(
      _completionHistoryKey,
      jsonEncode({
        for (final entry in dates.entries)
          entry.key.toString(): _dateKey(entry.value),
      }),
    );
    return values;
  }

  Future<void> clearProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_completedJuzKey);
    await prefs.remove(_completionHistoryKey);
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
