import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/kaza_prayer_tracking.dart';

class KazaPrayerService {
  static const _storageKey = 'kaza_prayer_tracking_v1';
  static const _historyLimit = 500;

  Future<void> _queue = Future<void>.value();

  Future<KazaPrayerSummary> loadSummary() async {
    final state = await _loadState();
    return _summary(state);
  }

  Future<KazaPrayerSummary> addDebt(KazaPrayerType prayer, int amount) {
    if (amount < 1 || amount > 100000) {
      throw ArgumentError.value(
          amount, 'amount', 'Miktar 1-100000 arasında olmalı.');
    }
    return _mutate((state) {
      state.debts[prayer] = (state.debts[prayer] ?? 0) + amount;
      state.history.insert(0, _transaction(prayer, amount));
    });
  }

  Future<KazaPrayerSummary> markPerformed(KazaPrayerType prayer,
      [int amount = 1]) {
    if (amount < 1 || amount > 100000) {
      throw ArgumentError.value(
          amount, 'amount', 'Miktar 1-100000 arasında olmalı.');
    }
    return _mutate((state) {
      final current = state.debts[prayer] ?? 0;
      final performed = amount.clamp(0, current);
      if (performed == 0) return;
      state.debts[prayer] = current - performed;
      state.history.insert(0, _transaction(prayer, -performed));
    });
  }

  Future<List<KazaPrayerTransaction>> loadHistory() async {
    final state = await _loadState();
    return List.unmodifiable(state.history);
  }

  Future<KazaPrayerSummary> _mutate(void Function(_KazaState state) operation) {
    final completer = Completer<KazaPrayerSummary>();
    _queue = _queue.then((_) async {
      try {
        final state = await _loadState();
        operation(state);
        if (state.history.length > _historyLimit) {
          state.history.removeRange(_historyLimit, state.history.length);
        }
        await _saveState(state);
        completer.complete(_summary(state));
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<_KazaState> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return _KazaState.empty();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final debts = <KazaPrayerType, int>{};
      final rawDebts = json['debts'];
      if (rawDebts is Map<String, dynamic>) {
        for (final entry in rawDebts.entries) {
          final prayer = KazaPrayerTypeX.fromId(entry.key);
          final value = entry.value;
          if (prayer != null && value is int && value >= 0) {
            debts[prayer] = value;
          }
        }
      }
      final history = <KazaPrayerTransaction>[];
      final rawHistory = json['history'];
      if (rawHistory is List) {
        for (final value in rawHistory) {
          if (value is! Map) continue;
          final item =
              KazaPrayerTransaction.fromJson(Map<String, dynamic>.from(value));
          if (item != null) history.add(item);
        }
      }
      return _KazaState(debts: debts, history: history);
    } catch (_) {
      return _KazaState.empty();
    }
  }

  Future<void> _saveState(_KazaState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode({
        'debts': {
          for (final entry in state.debts.entries) entry.key.id: entry.value
        },
        'history': state.history.map((item) => item.toJson()).toList(),
      }),
    );
  }

  KazaPrayerSummary _summary(_KazaState state) => KazaPrayerSummary(
        debts: {
          for (final type in KazaPrayerType.values) type: state.debts[type] ?? 0
        },
        history: List.unmodifiable(state.history),
      );

  KazaPrayerTransaction _transaction(KazaPrayerType prayer, int change) {
    final now = DateTime.now();
    return KazaPrayerTransaction(
      id: '${now.microsecondsSinceEpoch}_${prayer.id}',
      createdAt: now,
      prayer: prayer,
      change: change,
    );
  }
}

class _KazaState {
  final Map<KazaPrayerType, int> debts;
  final List<KazaPrayerTransaction> history;

  _KazaState({required this.debts, required this.history});

  factory _KazaState.empty() => _KazaState(debts: {}, history: []);
}
