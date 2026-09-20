import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/prayer_alarm_rule.dart';
import '../models/prayer_times.dart';
import '../models/turkish_city.dart';
import '../services/notification_service.dart';
import '../services/prayer_alarm_service.dart';
import '../services/ramadan_api_service.dart';
import '../services/ad_service.dart';
import '../theme/app_theme.dart';

const _days = <String>[
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar',
];

const _shortDays = <String>['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

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
          : 'Bildirimler ${last.day}.${last.month}.${last.year} tarihine kadar planlandı';
    });
  }

  Future<void> _save(List<PrayerAlarmRule> rules) async {
    setState(() => _busy = true);
    try {
      if (rules.any((rule) => rule.enabled) &&
          !await NotificationService().requestPermission()) {
        if (mounted) {
          setState(() {
            _status =
                'Bildirim izni verilmedi. Telefon ayarlarından izin verip tekrar deneyin.';
          });
        }
        return;
      }
      await _service.saveRules(rules);
      final count = await _service.refresh(force: true);
      await _load();
      if (mounted && count == 0 && rules.any((rule) => rule.enabled)) {
        setState(() {
          _status =
              'Kurallar kaydedildi; bildirimler şu an planlanamadı. Bağlantıyı ve izinleri kontrol edip Vakitleri Yenile’ye dokunun.';
        });
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
          initialCity: rule?.city ?? widget.initialCity,
          rule: rule,
        ),
      ),
    );
    if (value == null || !mounted) return;
    final rules = [..._rules];
    final index = rules.indexWhere((item) => item.id == value.id);
    if (index < 0) {
      rules.add(value);
    } else {
      rules[index] = value;
    }
    await _save(rules);
  }

  Future<void> _delete(PrayerAlarmRule rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: const Text('Alarm silinsin mi?'),
        content: Text('${rule.city.name} için oluşturulan alarm kaldırılacak.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _save(_rules.where((item) => item.id != rule.id).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        title: const Text('Namaz Alarmları'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const IconButton(
                  tooltip: 'Bildirimler',
                  onPressed: null,
                  icon: Icon(Icons.notifications_none_rounded,
                      color: AppTheme.navy),
                ),
                if (_rules.any((rule) => rule.enabled))
                  const Positioned(
                    right: 8,
                    top: 8,
                    child: CircleAvatar(
                      radius: 5,
                      backgroundColor: AppTheme.gold,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _busy
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppTheme.navy,
              foregroundColor: Colors.white,
              onPressed: () => _edit(),
              icon: const Icon(Icons.add_alarm_rounded),
              label: const Text('Yeni Alarm Ekle',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
      body: TopBannerAdBody(
        child: _busy
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 110),
                children: [
                  _buildInfoCard(),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Text(
                        'KAYITLI ALARMLAR',
                        style: TextStyle(
                          color: AppTheme.navy,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .7,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE5E9E7),
                          shape: BoxShape.circle,
                        ),
                        child: Text('${_rules.length}',
                            style: const TextStyle(
                                color: AppTheme.navy,
                                fontWeight: FontWeight.w800)),
                      ),
                      const Spacer(),
                      if (_rules.isNotEmpty)
                        Text(
                          _rules.every((rule) => rule.enabled)
                              ? 'Tümü Aktif'
                              : '${_rules.where((rule) => rule.enabled).length} Aktif',
                          style: const TextStyle(color: AppTheme.textMuted),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (final rule in _rules) ...[
                    _AlarmRuleCard(
                      rule: rule,
                      onEnabled: (value) => _save(_rules
                          .map((item) => item.id == rule.id
                              ? item.withEnabled(value)
                              : item)
                          .toList()),
                      onEdit: () => _edit(rule),
                      onDelete: () => _delete(rule),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (_rules.isEmpty) _buildEmptyState(),
                  if (_rules.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _buildAddHint(),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2DDD5)),
        boxShadow: AppTheme.ambientShadow,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.mint.withValues(alpha: .35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.info_outline_rounded,
                    color: AppTheme.emerald),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Akıllı Bildirim Yönetimi',
                        style: TextStyle(
                            color: AppTheme.navy,
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                    SizedBox(height: 5),
                    Text(
                      'Şehir, gün ve vakitlere göre alarm kurabilirsiniz. Sabah bildirimi imsak vaktine göre planlanır.',
                      style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                          height: 1.55),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  _status ?? 'Vakitler uygulama açıldığında yenilenir',
                  style:
                      const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: () => _save(_rules),
                icon: const Icon(Icons.refresh_rounded, size: 19),
                label: const Text('Vakitleri Yenile'),
                style: FilledButton.styleFrom(
                  foregroundColor: AppTheme.emerald,
                  backgroundColor: AppTheme.mint.withValues(alpha: .35),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: AppTheme.outline.withValues(alpha: .55),
              style: BorderStyle.solid),
        ),
        child: const Column(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Color(0xFFFFF2D4),
              child: Icon(Icons.add_alarm_rounded, color: AppTheme.gold),
            ),
            SizedBox(height: 14),
            Text('Henüz alarm oluşturmadınız',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppTheme.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            SizedBox(height: 6),
            Text(
              'Yeni bir namaz vakti uyarısı veya cuma hatırlatıcısı eklemek için butona dokunun.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, height: 1.5),
            ),
          ],
        ),
      );

  Widget _buildAddHint() => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: AppTheme.outline.withValues(alpha: .55),
              style: BorderStyle.solid),
        ),
        child: const Column(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Color(0xFFFFF2D4),
              child: Icon(Icons.warning_amber_rounded, color: AppTheme.gold),
            ),
            SizedBox(height: 12),
            Text('Yeni bir alarm mı kurmak istiyorsunuz?',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.navy)),
            SizedBox(height: 5),
            Text(
              'Yeni bir namaz vakti uyarısı eklemek için aşağıdaki butona dokunun.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
      );
}

class _AlarmRuleCard extends StatelessWidget {
  const _AlarmRuleCard({
    required this.rule,
    required this.onEnabled,
    required this.onEdit,
    required this.onDelete,
  });

  final PrayerAlarmRule rule;
  final ValueChanged<bool> onEnabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String get _daysLabel {
    final sorted = rule.weekdays.toList()..sort();
    if (sorted.length == 7) return 'Her Gün';
    if (sorted.length == 1) return _days[sorted.first - 1];
    return sorted.map((day) => _shortDays[day - 1]).join(', ');
  }

  String get _prayerLabel {
    if (rule.prayers.length == 1) return rule.prayers.first.label;
    return '${rule.prayers.length} Vakit';
  }

  @override
  Widget build(BuildContext context) {
    final lead =
        rule.leadMinutes == 0 ? 'Vaktinde' : '${rule.leadMinutes} dk önce';
    return AnimatedOpacity(
      opacity: rule.enabled ? 1 : .58,
      duration: const Duration(milliseconds: 180),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE8E5DE)),
          boxShadow: AppTheme.ambientShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF1F5),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.location_on_outlined,
                      color: AppTheme.navy),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(rule.city.name,
                      style: const TextStyle(
                          color: AppTheme.navy,
                          fontSize: 20,
                          fontWeight: FontWeight.w900)),
                ),
                Switch(value: rule.enabled, onChanged: onEnabled),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _RuleChip(
                    label: _daysLabel,
                    color: AppTheme.mint.withValues(alpha: .35),
                    foreground: AppTheme.emerald),
                _RuleChip(
                    label: _prayerLabel,
                    color: const Color(0xFFE9F0F4),
                    foreground: AppTheme.navy),
                _RuleChip(
                    label: lead,
                    icon: Icons.schedule_rounded,
                    color: const Color(0xFFFFF4DD),
                    foreground: const Color(0xFF946A00)),
              ],
            ),
            const SizedBox(height: 13),
            Text(
              '${rule.prayers.map((prayer) => prayer.label).join(', ')} için $lead bildirim gönderilir${rule.soundEnabled ? ' ve ses çalınır' : ''}.',
              style: const TextStyle(
                  color: AppTheme.textMuted, fontSize: 13, height: 1.5),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1),
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  label: const Text('Düzenle'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onDelete,
                  style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error),
                  child: const Text('Sil'),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Diğer seçenekler',
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                    PopupMenuItem(value: 'delete', child: Text('Sil')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleChip extends StatelessWidget {
  const _RuleChip({
    required this.label,
    required this.color,
    required this.foreground,
    this.icon,
  });

  final String label;
  final Color color;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 17, color: foreground),
              const SizedBox(width: 5),
            ],
            Text(label,
                style: TextStyle(
                    color: foreground,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ],
        ),
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
  late bool _soundEnabled;
  late bool _vibrate;
  PrayerTimes? _todayTimes;
  bool _loadingTimes = false;

  @override
  void initState() {
    super.initState();
    _city = widget.initialCity;
    _weekdays = {...?widget.rule?.weekdays};
    _prayers = {...?widget.rule?.prayers};
    _lead = widget.rule?.leadMinutes ?? 10;
    _soundEnabled = widget.rule?.soundEnabled ?? true;
    _vibrate = widget.rule?.vibrate ?? true;
    _loadPrayerTimes();
  }

  Future<void> _loadPrayerTimes() async {
    setState(() => _loadingTimes = true);
    final today = DateTime.now();
    try {
      final values = await RamadanApiService().fetchPrayerTimes(
        locationId: _city.id,
        startDate: DateTime(today.year, today.month, today.day),
        endDate: DateTime(today.year, today.month, today.day),
      );
      if (!mounted) return;
      setState(() => _todayTimes = values.firstOrNull);
    } catch (_) {
      if (mounted) setState(() => _todayTimes = null);
    } finally {
      if (mounted) setState(() => _loadingTimes = false);
    }
  }

  String _timeFor(AlarmPrayer prayer) =>
      _todayTimes == null ? '--:--' : prayer.timeOf(_todayTimes!);

  void _applyDays(Set<int> days) => setState(() => _weekdays = {...days});

  void _save() {
    if (_weekdays.isEmpty || _prayers.isEmpty) return;
    Navigator.pop(
      context,
      PrayerAlarmRule(
        id: widget.rule?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        city: _city,
        weekdays: _weekdays,
        prayers: _prayers,
        leadMinutes: _lead,
        enabled: widget.rule?.enabled ?? true,
        soundEnabled: _soundEnabled,
        vibrate: _vibrate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _weekdays.isNotEmpty && _prayers.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        title: Text(widget.rule == null
            ? 'Yeni Namaz Alarmı'
            : 'Namaz Alarmını Düzenle'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        child: FilledButton.icon(
          onPressed: canSave ? _save : null,
          icon: const Icon(Icons.notifications_none_rounded),
          label: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [Text('Alarmı '), Text('Kaydet')],
            ),
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(58),
            textStyle: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
      body: TopBannerAdBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            const _SectionTitle('ŞEHİR SEÇİMİ'),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _city.id,
              isExpanded: true,
              decoration: InputDecoration(
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.mint.withValues(alpha: .35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.location_on_outlined,
                        color: AppTheme.emerald),
                  ),
                ),
                labelText: 'Konum / Şehir',
              ),
              items: PrayerAlarmService.cities
                  .map(
                    (city) => DropdownMenuItem(
                      value: city.id,
                      child: Text('${city.name}, Türkiye',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppTheme.navy,
                              fontWeight: FontWeight.w800)),
                    ),
                  )
                  .toList(),
              onChanged: (id) {
                if (id == null) return;
                setState(() {
                  _city = PrayerAlarmService.cities
                      .firstWhere((city) => city.id == id);
                });
                _loadPrayerTimes();
              },
            ),
            const SizedBox(height: 28),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              runAlignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                const _SectionTitle('HANGİ GÜNLER?'),
                Text('${_weekdays.length} gün seçildi',
                    style:
                        const TextStyle(color: AppTheme.emerald, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PresetChip(
                    label: 'Her gün',
                    selected: _weekdays.length == 7,
                    onTap: () => _applyDays({1, 2, 3, 4, 5, 6, 7})),
                _PresetChip(
                    label: 'Hafta içi',
                    selected: _weekdays.length == 5 &&
                        _weekdays.containsAll({1, 2, 3, 4, 5}),
                    onTap: () => _applyDays({1, 2, 3, 4, 5})),
                _PresetChip(
                    label: 'Hafta sonu',
                    selected:
                        _weekdays.length == 2 && _weekdays.containsAll({6, 7}),
                    onTap: () => _applyDays({6, 7})),
                _PresetChip(
                    label: 'Yalnız cuma öğle',
                    selected: _weekdays.length == 1 && _weekdays.contains(5),
                    onTap: () => setState(() {
                          _weekdays = {5};
                          _prayers = {AlarmPrayer.dhuhr};
                        })),
              ],
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 7,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 9,
                crossAxisSpacing: 9,
                childAspectRatio: 1.28,
              ),
              itemBuilder: (context, index) {
                final day = index + 1;
                final selected = _weekdays.contains(day);
                return _DayTile(
                  short: _shortDays[index],
                  long: _days[index],
                  selected: selected,
                  onTap: () => setState(() {
                    selected ? _weekdays.remove(day) : _weekdays.add(day);
                  }),
                );
              },
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                const _SectionTitle('HANGİ VAKİTLER?'),
                if (_loadingTimes) ...[
                  const SizedBox(width: 10),
                  const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ],
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: AlarmPrayer.values.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.78,
              ),
              itemBuilder: (context, index) {
                final prayer = AlarmPrayer.values[index];
                final selected = _prayers.contains(prayer);
                return _PrayerTile(
                  prayer: prayer,
                  time: _timeFor(prayer),
                  selected: selected,
                  onTap: () => setState(() {
                    selected ? _prayers.remove(prayer) : _prayers.add(prayer);
                  }),
                );
              },
            ),
            const SizedBox(height: 28),
            const _SectionTitle('BİLDİRİM ZAMANI'),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              initialValue: _lead,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.schedule_outlined, color: AppTheme.navy),
                labelText: 'Uyarının Çalacağı Vakit',
              ),
              items: ({0, 5, 10, 15, 30, 60, _lead}.toList()..sort())
                  .map(
                    (minutes) => DropdownMenuItem(
                      value: minutes,
                      child: Text(
                          minutes == 0 ? 'Vaktinde' : '$minutes dakika önce'),
                    ),
                  )
                  .toList(),
              onChanged: (minutes) => setState(() => _lead = minutes ?? 10),
            ),
            const SizedBox(height: 28),
            const _SectionTitle('BİLDİRİM VE SES AYARLARI'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2DDD5)),
                boxShadow: AppTheme.ambientShadow,
              ),
              child: Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      secondary: const Icon(Icons.volume_up_outlined,
                          color: AppTheme.navy),
                      title: const Text('Bildirim Sesi',
                          style: TextStyle(
                              color: AppTheme.navy,
                              fontWeight: FontWeight.w800)),
                      subtitle: Text(_soundEnabled
                          ? 'Telefonun namaz bildirimi sesi'
                          : 'Sessiz bildirim'),
                      value: _soundEnabled,
                      onChanged: (value) =>
                          setState(() => _soundEnabled = value),
                    ),
                  ),
                  const Divider(height: 1),
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      secondary: const Icon(Icons.vibration_rounded,
                          color: AppTheme.navy),
                      title: const Text('Titreşim',
                          style: TextStyle(
                              color: AppTheme.navy,
                              fontWeight: FontWeight.w800)),
                      subtitle: const Text('Sessiz modda bildirim uyarısı'),
                      value: _vibrate,
                      onChanged: (value) => setState(() => _vibrate = value),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: Color(0xFF426A7C),
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.1,
        ),
      );
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppTheme.navy,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppTheme.textMuted,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
        ),
        side: BorderSide(
          color: selected ? AppTheme.navy : const Color(0xFFE2DDD5),
        ),
        showCheckmark: false,
      );
}

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.short,
    required this.long,
    required this.selected,
    required this.onTap,
  });

  final String short;
  final String long;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? AppTheme.navy : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: selected ? AppTheme.navy : const Color(0xFFE2DDD5)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(short,
                    style: TextStyle(
                        color: selected ? Colors.white : AppTheme.text,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(long,
                      style: TextStyle(
                          color: selected ? AppTheme.mint : AppTheme.textMuted,
                          fontSize: 9)),
                ),
              ],
            ),
          ),
        ),
      );
}

class _PrayerTile extends StatelessWidget {
  const _PrayerTile({
    required this.prayer,
    required this.time,
    required this.selected,
    required this.onTap,
  });

  final AlarmPrayer prayer;
  final String time;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (prayer) {
        AlarmPrayer.fajr => Icons.nights_stay_outlined,
        AlarmPrayer.sunrise => Icons.wb_twilight_outlined,
        AlarmPrayer.dhuhr => Icons.light_mode_outlined,
        AlarmPrayer.asr => Icons.wb_sunny_outlined,
        AlarmPrayer.maghrib => Icons.wb_twilight_rounded,
        AlarmPrayer.isha => Icons.dark_mode_outlined,
      };

  String get _label => prayer == AlarmPrayer.fajr ? 'Sabah' : prayer.label;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? AppTheme.emerald : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: selected ? AppTheme.emerald : const Color(0xFFE2DDD5)),
              boxShadow: selected ? null : AppTheme.ambientShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: .18)
                        : const Color(0xFFFFF4DD),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_icon,
                      color: selected ? Colors.white : AppTheme.gold, size: 21),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: selected ? Colors.white : AppTheme.navy,
                              fontWeight: FontWeight.w900)),
                      Text(time,
                          style: TextStyle(
                              color:
                                  selected ? AppTheme.mint : AppTheme.textMuted,
                              fontSize: 11)),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? Colors.white : AppTheme.outline,
                  size: 21,
                ),
              ],
            ),
          ),
        ),
      );
}
