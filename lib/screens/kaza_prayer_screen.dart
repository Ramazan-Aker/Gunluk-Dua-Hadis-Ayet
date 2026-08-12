import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/kaza_prayer_tracking.dart';
import '../services/kaza_prayer_service.dart';
import '../theme/app_theme.dart';

class KazaPrayerScreen extends StatefulWidget {
  final KazaPrayerService? service;

  const KazaPrayerScreen({super.key, this.service});

  @override
  State<KazaPrayerScreen> createState() => _KazaPrayerScreenState();
}

class _KazaPrayerScreenState extends State<KazaPrayerScreen> {
  late final KazaPrayerService _service = widget.service ?? KazaPrayerService();
  KazaPrayerSummary? _summary;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final summary = await _service.loadSummary();
    if (mounted) setState(() => _summary = summary);
  }

  Future<void> _addDebt([KazaPrayerType? initialPrayer]) async {
    final result = await showModalBottomSheet<(KazaPrayerType, int)>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AddDebtSheet(initialPrayer: initialPrayer),
    );
    if (result == null) return;
    await _run(() => _service.addDebt(result.$1, result.$2));
  }

  Future<void> _markPerformed(KazaPrayerType prayer) async {
    if ((_summary?.debtFor(prayer) ?? 0) == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${prayer.label} için kayıtlı borç bulunmuyor.')),
      );
      return;
    }
    await _run(() => _service.markPerformed(prayer));
  }

  Future<void> _run(Future<KazaPrayerSummary> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final summary = await operation();
      if (mounted) setState(() => _summary = summary);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    return Scaffold(
      backgroundColor: AppTheme.ivory,
      appBar: AppBar(
        title: const Text('Kaza Namazı Takibi'),
        actions: [
          IconButton(
            tooltip: 'Kaza borcu ekle',
            onPressed: _busy ? null : () => _addDebt(),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: summary == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _SummaryCard(
                    summary: summary, onAdd: _busy ? null : () => _addDebt()),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: AppTheme.mint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_outline_rounded,
                          color: AppTheme.emerald, size: 20),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Bu alan kişisel takip içindir; veriler yalnızca cihazınızda saklanır. Dini hüküm veya borç hesabı yerine geçmez.',
                          style: TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              color: AppTheme.navy),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text('Namazlara göre',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.navy)),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = (constraints.maxWidth - 10) / 2;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final prayer in KazaPrayerType.values)
                          SizedBox(
                            width: width,
                            child: _PrayerDebtCard(
                              prayer: prayer,
                              debt: summary.debtFor(prayer),
                              busy: _busy,
                              onAdd: () => _addDebt(prayer),
                              onPerformed: () => _markPerformed(prayer),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 22),
                const Text('Son hareketler',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.navy)),
                const SizedBox(height: 8),
                if (summary.history.isEmpty)
                  const _EmptyHistory()
                else
                  ...summary.history
                      .take(20)
                      .map((item) => _HistoryTile(item: item)),
              ],
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final KazaPrayerSummary summary;
  final VoidCallback? onAdd;

  const _SummaryCard({required this.summary, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppTheme.navy, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Toplam kaza borcu',
              style: TextStyle(
                  color: Color(0xFFD8F5EC), fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('${summary.totalDebt}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w900)),
          Text('${summary.totalPerformed} kaza namazı tamamlandı',
              style: const TextStyle(
                  color: AppTheme.gold, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                foregroundColor: Colors.white),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Kaza borcu ekle'),
          ),
        ],
      ),
    );
  }
}

class _PrayerDebtCard extends StatelessWidget {
  final KazaPrayerType prayer;
  final int debt;
  final bool busy;
  final VoidCallback onAdd;
  final VoidCallback onPerformed;

  const _PrayerDebtCard({
    required this.prayer,
    required this.debt,
    required this.busy,
    required this.onAdd,
    required this.onPerformed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppTheme.outline.withValues(alpha: .25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(prayer.label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, color: AppTheme.navy))),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: '${prayer.label} borcu ekle',
                onPressed: busy ? null : onAdd,
                icon: const Icon(Icons.add_circle_outline_rounded,
                    color: AppTheme.emerald),
              ),
            ],
          ),
          Text('$debt',
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.navy)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: busy || debt == 0 ? null : onPerformed,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Kıldım'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final KazaPrayerTransaction item;
  const _HistoryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 2),
      leading: CircleAvatar(
        backgroundColor: item.isPerformed
            ? AppTheme.mint
            : AppTheme.gold.withValues(alpha: .22),
        foregroundColor: item.isPerformed ? AppTheme.emerald : AppTheme.navy,
        child: Icon(item.isPerformed ? Icons.check_rounded : Icons.add_rounded),
      ),
      title: Text('${item.prayer.label} • ${item.amount}',
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(DateFormat('dd.MM.yyyy, HH:mm').format(item.createdAt)),
      trailing: Text(item.isPerformed ? 'Kılındı' : 'Eklendi',
          style: TextStyle(
              fontWeight: FontWeight.w700,
              color: item.isPerformed ? AppTheme.emerald : AppTheme.navy)),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: const Text('Henüz bir hareket yok.',
            style: TextStyle(color: AppTheme.outline)),
      );
}

class _AddDebtSheet extends StatefulWidget {
  final KazaPrayerType? initialPrayer;
  const _AddDebtSheet({this.initialPrayer});

  @override
  State<_AddDebtSheet> createState() => _AddDebtSheetState();
}

class _AddDebtSheetState extends State<_AddDebtSheet> {
  late KazaPrayerType _prayer = widget.initialPrayer ?? KazaPrayerType.fajr;
  final _controller = TextEditingController(text: '1');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = int.tryParse(_controller.text.trim());
    if (amount == null || amount < 1 || amount > 100000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('1 ile 100000 arasında bir sayı girin.')),
      );
      return;
    }
    Navigator.pop(context, (_prayer, amount));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 18, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Kaza borcu ekle',
              style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navy)),
          const SizedBox(height: 18),
          DropdownButtonFormField<KazaPrayerType>(
            initialValue: _prayer,
            decoration: const InputDecoration(labelText: 'Namaz'),
            items: [
              for (final prayer in KazaPrayerType.values)
                DropdownMenuItem(value: prayer, child: Text(prayer.label))
            ],
            onChanged: (value) {
              if (value != null) setState(() => _prayer = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration:
                const InputDecoration(labelText: 'Adet', hintText: 'Örn. 30'),
          ),
          const SizedBox(height: 18),
          FilledButton(onPressed: _submit, child: const Text('Borcu ekle')),
        ],
      ),
    );
  }
}
