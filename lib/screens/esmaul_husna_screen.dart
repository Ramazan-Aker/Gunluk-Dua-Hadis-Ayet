import 'package:flutter/material.dart';

import '../models/esmaul_husna_name.dart';
import '../models/esmaul_husna_progress.dart';
import '../services/esmaul_husna_audio_service.dart';
import '../services/esmaul_husna_service.dart';
import '../theme/app_theme.dart';

enum _EsmaFilter { all, favorites, memorized }

class EsmaulHusnaScreen extends StatefulWidget {
  final EsmaulHusnaService? service;

  const EsmaulHusnaScreen({super.key, this.service});

  @override
  State<EsmaulHusnaScreen> createState() => _EsmaulHusnaScreenState();
}

class _EsmaulHusnaScreenState extends State<EsmaulHusnaScreen> {
  late final EsmaulHusnaService _service =
      widget.service ?? EsmaulHusnaService();
  final _audio = EsmaulHusnaAudioService();
  final _searchController = TextEditingController();
  EsmaulHusnaProgress _progress = const EsmaulHusnaProgress();
  _EsmaFilter _filter = _EsmaFilter.all;
  String _query = '';
  int? _speakingNumber;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _audio.stop();
    super.dispose();
  }

  Future<void> _load() async {
    final progress = await _service.loadProgress();
    if (mounted) {
      setState(() {
        _progress = progress;
        _loading = false;
      });
    }
  }

  Future<void> _toggleFavorite(int number) async {
    final progress = await _service.toggleFavorite(number);
    if (mounted) setState(() => _progress = progress);
  }

  Future<void> _toggleMemorized(int number) async {
    final progress = await _service.toggleMemorized(number);
    if (!mounted) return;
    setState(() => _progress = progress);
    if (progress.memorized.contains(number)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ezberlendi olarak işaretlendi.')),
      );
    }
  }

  Future<void> _speak(EsmaulHusnaName name) async {
    setState(() => _speakingNumber = name.number);
    try {
      await _audio.speak(name.latin);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Türkçe ses kullanılamadı. Cihazın konuşma motorunu kontrol edin.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _speakingNumber = null);
    }
  }

  List<EsmaulHusnaName> get _visibleNames {
    final query = _normalize(_query.trim());
    return esmaulHusnaNames.where((name) {
      final matchesFilter = switch (_filter) {
        _EsmaFilter.all => true,
        _EsmaFilter.favorites => _progress.favorites.contains(name.number),
        _EsmaFilter.memorized => _progress.memorized.contains(name.number),
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      return _normalize(
              '${name.number} ${name.latin} ${name.arabic} ${name.meaning}')
          .contains(query);
    }).toList();
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[âäáà]'), 'a')
      .replaceAll(RegExp('[îïíì]'), 'i')
      .replaceAll(RegExp('[ûüúù]'), 'u')
      .replaceAll('ş', 's')
      .replaceAll('ç', 'c')
      .replaceAll('ğ', 'g')
      .replaceAll('ö', 'o')
      .replaceAll('ı', 'i');

  @override
  Widget build(BuildContext context) {
    final names = _visibleNames;
    return Scaffold(
      backgroundColor: AppTheme.ivory,
      appBar: AppBar(title: const Text('Esmaül Hüsna')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildSearchAndFilters()),
                if (names.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('Bu filtrede isim bulunamadı.')),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    sliver: SliverList.separated(
                      itemCount: names.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _NameCard(
                        name: names[index],
                        favorite:
                            _progress.favorites.contains(names[index].number),
                        memorized:
                            _progress.memorized.contains(names[index].number),
                        speaking: _speakingNumber == names[index].number,
                        onFavorite: () => _toggleFavorite(names[index].number),
                        onMemorized: () =>
                            _toggleMemorized(names[index].number),
                        onSpeak: () => _speak(names[index]),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    final memorized = _progress.memorized.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.navy,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.mint,
                foregroundColor: AppTheme.emerald,
                child: Icon(Icons.auto_awesome_rounded),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Allah’ın 99 Güzel İsmi',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: _progress.memorizedRatio,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(AppTheme.gold),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$memorized/99 isim ezberlendi • ${_progress.favorites.length} favori',
            style: const TextStyle(
                color: Color(0xFFD8F5EC), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'İsim veya anlam ara',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Aramayı temizle',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip(_EsmaFilter.all, 'Tümü', Icons.grid_view_rounded),
                const SizedBox(width: 8),
                _filterChip(
                    _EsmaFilter.favorites, 'Favoriler', Icons.favorite_rounded),
                const SizedBox(width: 8),
                _filterChip(_EsmaFilter.memorized, 'Ezberlenenler',
                    Icons.school_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(_EsmaFilter filter, String label, IconData icon) {
    return FilterChip(
      selected: _filter == filter,
      onSelected: (_) => setState(() => _filter = filter),
      avatar: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _NameCard extends StatelessWidget {
  final EsmaulHusnaName name;
  final bool favorite;
  final bool memorized;
  final bool speaking;
  final VoidCallback onFavorite;
  final VoidCallback onMemorized;
  final VoidCallback onSpeak;

  const _NameCard({
    required this.name,
    required this.favorite,
    required this.memorized,
    required this.speaking,
    required this.onFavorite,
    required this.onMemorized,
    required this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
            color: memorized
                ? AppTheme.emerald.withValues(alpha: .45)
                : AppTheme.outline.withValues(alpha: .25)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: AppTheme.mint,
                  foregroundColor: AppTheme.emerald,
                  child: Text('${name.number}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.arabic,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.navy)),
                      const SizedBox(height: 3),
                      Text(name.latin,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.emerald)),
                      const SizedBox(height: 5),
                      Text(name.meaning,
                          style: const TextStyle(
                              height: 1.35, color: AppTheme.navyContainer)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: favorite ? 'Favorilerden çıkar' : 'Favorilere ekle',
                  onPressed: onFavorite,
                  icon: Icon(
                      favorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: favorite ? Colors.redAccent : AppTheme.outline),
                ),
                IconButton(
                  tooltip: memorized
                      ? 'Ezber işaretini kaldır'
                      : 'Ezberlendi işaretle',
                  onPressed: onMemorized,
                  icon: Icon(
                      memorized ? Icons.school_rounded : Icons.school_outlined,
                      color: memorized ? AppTheme.emerald : AppTheme.outline),
                ),
                IconButton(
                  tooltip: 'Arapça dinle',
                  onPressed: speaking ? null : onSpeak,
                  icon: speaking
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.volume_up_rounded,
                          color: AppTheme.navy),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
