import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prayer_alarm_rule.dart';
import '../models/turkish_city.dart';
import '../services/notification_service.dart';
import '../services/prayer_alarm_service.dart';

const _days = [
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar'
];

class PrayerAlarmScreen extends StatefulWidget {
  const PrayerAlarmScreen({super.key, required this.initialCity});
  final TurkishCity initialCity;
  @override
  State<PrayerAlarmScreen> createState() => _PrayerAlarmScreenState();
}

class _PrayerAlarmScreenState extends State<PrayerAlarmScreen> {
  final _service = PrayerAlarmService();
  List<PrayerAlarmRule> _rules = [];
  bool _busy = true;
  String? _status;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rules = await _service.loadRules();
    final prefs = await SharedPreferences.getInstance();
    final last =
        DateTime.tryParse(prefs.getString(PrayerAlarmService.horizonKey) ?? '');
    if (!mounted) return;
    setState(() {
      _rules = rules;
      _busy = false;
      _status = last == null
          ? null
          : 'Son planlanan bildirim: ${last.day}.${last.month}.${last.year}';
    });
  }

  Future<void> _save(List<PrayerAlarmRule> rules) async {
    setState(() => _busy = true);
    try {
      if (rules.any((r) => r.enabled) &&
          !await NotificationService().requestPermission()) {
        if (mounted) {
          setState(() => _status =
              'Bildirim izni verilmedi. Telefon ayarlarından izin verip tekrar deneyin.');
        }
        return;
      }
      await _service.saveRules(rules);
      final count = await _service.refresh(force: true);
      await _load();
      if (mounted && count == 0 && rules.any((r) => r.enabled)) {
        setState(() => _status =
            'Kurallar kaydedildi, ancak bildirim planlanamadı. Bağlantı ve bildirim izinlerini kontrol edip Yenile’ye basın.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _status = 'Ayarlar kaydedilemedi. Tekrar deneyin.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([PrayerAlarmRule? rule]) async {
    final value = await Navigator.of(context).push<PrayerAlarmRule>(
        MaterialPageRoute(
            builder: (_) => PrayerAlarmEditor(
                initialCity: rule?.city ?? widget.initialCity, rule: rule)));
    if (value == null || !mounted) return;
    final rules = [..._rules];
    final index = rules.indexWhere((r) => r.id == value.id);
    if (index < 0) {
      rules.add(value);
    } else {
      rules[index] = value;
    }
    await _save(rules);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Namaz alarmları')),
        floatingActionButton: _busy
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _edit(),
                icon: const Icon(Icons.add_alarm),
                label: const Text('Kural ekle')),
        body: _busy
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: [
                    const Text(
                        'Her şehir için günleri ve vakitleri ayrı seçebilirsiniz. Sabah bildirimi imsak saatine göre planlanır.'),
                    const SizedBox(height: 12),
                    if (_status != null)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(_status!)),
                    const Text(
                        'Vakitler uygulama açıldığında yenilenir. Bildirimlerin devamı için uygulamayı düzenli açın.',
                        style: TextStyle(fontSize: 12)),
                    TextButton.icon(
                        onPressed: () => _save(_rules),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Yenile')),
                    if (_rules.isEmpty)
                      const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                              'Henüz alarm kuralı yok. Örneğin yalnız cuma öğle için bir kural ekleyin.')),
                    for (final rule in _rules)
                      Card(
                          child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Expanded(
                                          child: Text(rule.city.name,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium)),
                                      Switch(
                                          value: rule.enabled,
                                          onChanged: (value) => _save(_rules
                                              .map((r) => r.id == rule.id
                                                  ? r.withEnabled(value)
                                                  : r)
                                              .toList()))
                                    ]),
                                    Text((rule.weekdays.toList()..sort())
                                        .map((d) => _days[d - 1])
                                        .join(', ')),
                                    Text(rule.prayers
                                        .map((p) => p.label)
                                        .join(', ')),
                                    Text(rule.leadMinutes == 0
                                        ? 'Vaktinde'
                                        : '${rule.leadMinutes} dakika önce'),
                                    Wrap(children: [
                                      TextButton(
                                          onPressed: () => _edit(rule),
                                          child: const Text('Düzenle')),
                                      TextButton(
                                          onPressed: () => _save(_rules
                                              .where((r) => r.id != rule.id)
                                              .toList()),
                                          child: const Text('Sil'))
                                    ]),
                                  ]))),
                  ]),
      );
}

class PrayerAlarmEditor extends StatefulWidget {
  const PrayerAlarmEditor({super.key, required this.initialCity, this.rule});
  final TurkishCity initialCity;
  final PrayerAlarmRule? rule;
  @override
  State<PrayerAlarmEditor> createState() => _PrayerAlarmEditorState();
}

class _PrayerAlarmEditorState extends State<PrayerAlarmEditor> {
  late TurkishCity _city;
  late Set<int> _weekdays;
  late Set<AlarmPrayer> _prayers;
  late int _lead;
  @override
  void initState() {
    super.initState();
    _city = widget.initialCity;
    _weekdays = {...?widget.rule?.weekdays};
    _prayers = {...?widget.rule?.prayers};
    _lead = widget.rule?.leadMinutes ?? 10;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(
                widget.rule == null ? 'Alarm kuralı ekle' : 'Alarmı düzenle')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          DropdownButtonFormField<String>(
              initialValue: _city.id,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Şehir'),
              items: PrayerAlarmService.cities
                  .map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                  .toList(),
              onChanged: (id) => setState(() => _city =
                  PrayerAlarmService.cities.firstWhere((c) => c.id == id))),
          const SizedBox(height: 20),
          const Text('Hangi günler?'),
          Wrap(spacing: 6, children: [
            for (var d = 1; d <= 7; d++)
              FilterChip(
                  label: Text(_days[d - 1]),
                  selected: _weekdays.contains(d),
                  onSelected: (selected) => setState(() {
                        selected ? _weekdays.add(d) : _weekdays.remove(d);
                      }))
          ]),
          Wrap(children: [
            TextButton(
                onPressed: () =>
                    setState(() => _weekdays = {1, 2, 3, 4, 5, 6, 7}),
                child: const Text('Her gün')),
            TextButton(
                onPressed: () => setState(() {
                      _weekdays = {5};
                      _prayers = {AlarmPrayer.dhuhr};
                    }),
                child: const Text('Yalnız cuma öğle'))
          ]),
          const SizedBox(height: 12),
          const Text('Hangi vakitler?'),
          Wrap(spacing: 6, children: [
            for (final p in AlarmPrayer.values)
              FilterChip(
                  label: Text(p.label),
                  selected: _prayers.contains(p),
                  onSelected: (selected) => setState(() {
                        selected ? _prayers.add(p) : _prayers.remove(p);
                      }))
          ]),
          const SizedBox(height: 20),
          DropdownButtonFormField<int>(
              initialValue: _lead,
              decoration: const InputDecoration(labelText: 'Ne zaman?'),
              items: ({0, 5, 10, 15, 30, 60, _lead}.toList()..sort())
                  .map((n) => DropdownMenuItem(
                      value: n,
                      child: Text(n == 0 ? 'Vaktinde' : '$n dakika önce')))
                  .toList(),
              onChanged: (n) => setState(() => _lead = n ?? 10)),
          const SizedBox(height: 24),
          FilledButton(
              onPressed: _weekdays.isEmpty || _prayers.isEmpty
                  ? null
                  : () => Navigator.pop(
                      context,
                      PrayerAlarmRule(
                          id: widget.rule?.id ??
                              DateTime.now().microsecondsSinceEpoch.toString(),
                          city: _city,
                          weekdays: _weekdays,
                          prayers: _prayers,
                          leadMinutes: _lead,
                          enabled: widget.rule?.enabled ?? true)),
              child: const Text('Kaydet')),
        ]),
      );
}
