import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/dhikr_tracking.dart';

class DhikrTrackingService {
  static const _storageKey = 'dhikr_tracking_state_v1';
  static const _retentionDays = 400;

  Future<_DhikrState>? _stateFuture;
  Future<void> _writeQueue = Future<void>.value();

  Future<DhikrTrackingSummary> loadSummary({
    DateTime? now,
    bool forceReload = false,
  }) async {
    if (forceReload) _stateFuture = null;
    final state = await (_stateFuture ??= _loadState());
    return _summary(state, _dateOnly(now ?? DateTime.now()));
  }

  Future<List<DhikrDayProgress>> loadHistory({
    bool forceReload = false,
  }) async {
    if (forceReload) _stateFuture = null;
    final state = await (_stateFuture ??= _loadState());
    return state.days.values.toList()
      ..sort((first, second) => first.date.compareTo(second.date));
  }

  Future<DhikrTrackingSummary> increment({DateTime? now}) {
    return _enqueue((state) async {
      final today = _dateOnly(now ?? DateTime.now());
      final option = DhikrOption.fromId(state.selectedId);
      final target = state.targets[option.id] ?? option.defaultTarget;
      final current = state.days[today] ?? _emptyDay(today);
      final counts = Map<String, int>.from(current.counts);
      final newCount = (counts[option.id] ?? 0) + 1;
      counts[option.id] = newCount;
      state.days[today] = current.copyWith(
        counts: counts,
        goalMet: current.goalMet || newCount >= target,
      );
      await _persist(state, today);
      return _summary(state, today);
    });
  }

  Future<DhikrTrackingSummary> selectOption(
    String optionId, {
    DateTime? now,
  }) {
    return _enqueue((state) async {
      final option = DhikrOption.fromId(optionId);
      state.selectedId = option.id;
      final today = _dateOnly(now ?? DateTime.now());
      await _persist(state, today);
      return _summary(state, today);
    });
  }

  Future<DhikrTrackingSummary> setTarget(
    int target, {
    DateTime? now,
  }) {
    if (target < 1 || target > 9999) {
      throw ArgumentError.value(
          target, 'target', 'Hedef 1-9999 arasında olmalı');
    }
    return _enqueue((state) async {
      final today = _dateOnly(now ?? DateTime.now());
      final option = DhikrOption.fromId(state.selectedId);
      state.targets[option.id] = target;
      final current = state.days[today] ?? _emptyDay(today);
      if (current.countFor(option.id) >= target && !current.goalMet) {
        state.days[today] = current.copyWith(goalMet: true);
      }
      await _persist(state, today);
      return _summary(state, today);
    });
  }

  Future<DhikrTrackingSummary> resetCurrent({DateTime? now}) {
    return _enqueue((state) async {
      final today = _dateOnly(now ?? DateTime.now());
      final option = DhikrOption.fromId(state.selectedId);
      final current = state.days[today] ?? _emptyDay(today);
      final counts = Map<String, int>.from(current.counts)..[option.id] = 0;
      state.days[today] = current.copyWith(counts: counts);
      await _persist(state, today);
      return _summary(state, today);
    });
  }

  Future<T> _enqueue<T>(Future<T> Function(_DhikrState state) operation) {
    final completer = Completer<T>();
    _writeQueue = _writeQueue.then((_) async {
      try {
        final state = await (_stateFuture ??= _loadState());
        completer.complete(await operation(state));
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<_DhikrState> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return _DhikrState.empty();
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final targets = <String, int>{};
      final rawTargets = decoded['targets'];
      if (rawTargets is Map<String, dynamic>) {
        for (final entry in rawTargets.entries) {
          final value = entry.value;
          if (value is int && value >= 1 && value <= 9999) {
            targets[entry.key] = value;
          }
        }
      }
      final days = <DateTime, DhikrDayProgress>{};
      final rawDays = decoded['days'];
      if (rawDays is Map<String, dynamic>) {
        for (final entry in rawDays.entries) {
          final date = DateTime.tryParse(entry.key);
          final value = entry.value;
          if (date == null || value is! Map<String, dynamic>) continue;
          final normalized = _dateOnly(date);
          days[normalized] = DhikrDayProgress.fromJson(normalized, value);
        }
      }
      return _DhikrState(
        selectedId: DhikrOption.fromId(decoded['selectedId'] as String?).id,
        targets: targets,
        days: days,
      );
    } catch (_) {
      return _DhikrState.empty();
    }
  }

  Future<void> _persist(_DhikrState state, DateTime today) async {
    final oldest = today.subtract(const Duration(days: _retentionDays));
    state.days.removeWhere((date, _) => date.isBefore(oldest));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode({
        'selectedId': state.selectedId,
        'targets': state.targets,
        'days': {
          for (final entry in state.days.entries)
            _dateKey(entry.key): entry.value.toJson(),
        },
      }),
    );
  }

  DhikrTrackingSummary _summary(_DhikrState state, DateTime today) {
    final option = DhikrOption.fromId(state.selectedId);
    final target = state.targets[option.id] ?? option.defaultTarget;
    final todayProgress = state.days[today] ?? _emptyDay(today);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final week = List.generate(7, (index) {
      final date = weekStart.add(Duration(days: index));
      return state.days[date] ?? _emptyDay(date);
    });
    return DhikrTrackingSummary(
      option: option,
      today: todayProgress,
      target: target,
      week: week,
      currentStreak: _currentStreak(state.days, today),
      longestStreak: _longestStreak(state.days),
    );
  }

  int _currentStreak(Map<DateTime, DhikrDayProgress> days, DateTime today) {
    var cursor = today;
    var streak = 0;
    for (var checked = 0; checked <= _retentionDays; checked++) {
      final progress = days[cursor];
      if (progress?.goalMet == true) {
        streak++;
      } else if (cursor != today) {
        break;
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int _longestStreak(Map<DateTime, DhikrDayProgress> days) {
    if (days.isEmpty) return 0;
    final dates = days.keys.toList()..sort();
    var longest = 0;
    var current = 0;
    var cursor = dates.first;
    while (!cursor.isAfter(dates.last)) {
      if (days[cursor]?.goalMet == true) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 0;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return longest;
  }

  static DhikrDayProgress _emptyDay(DateTime date) => DhikrDayProgress(
        date: date,
        counts: const {},
      );

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

class _DhikrState {
  _DhikrState({
    required this.selectedId,
    required this.targets,
    required this.days,
  });

  String selectedId;
  final Map<String, int> targets;
  final Map<DateTime, DhikrDayProgress> days;

  factory _DhikrState.empty() => _DhikrState(
        selectedId: DhikrOption.presets.first.id,
        targets: {},
        days: {},
      );
}
