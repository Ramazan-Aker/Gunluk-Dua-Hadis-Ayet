import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/quran_audio_service.dart';
import '../services/ad_service.dart';
import '../services/firebase_service.dart'
    show FirebaseService, AnalyticsEvents, AnalyticsParams;
import '../services/quran_offline_repository.dart';
import '../widgets/widget_shortcut_helper.dart';
import '../widget_verse_pending.dart';
import 'surah_detail_screen.dart';
import 'juz_list_screen.dart';
import '../theme/app_theme.dart';

/// Quran screen - Sesli Kur'an-ı Kerim okuma
class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  final QuranAudioService _audioService = QuranAudioService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<QuranSurahInfo> _surahs = [];
  List<QuranSurahInfo> _filteredSurahs = [];
  int? _lastReadSurah;
  String _searchQuery = '';

  static const String _keyLastRead = 'quran_last_read_surah';
  static const String _keyLastVerse =
      'quran_last_verse_'; // Prefix for verse position per surah

  @override
  void initState() {
    super.initState();
    _surahs = _audioService.getAllSurahs();
    _filteredSurahs = _surahs; // Initially show all surahs
    pendingWidgetVerseListIndex.addListener(_onPendingWidgetVerseFromWidget);
    // Defer non-critical work to avoid blocking first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedPreferences();
      FirebaseService.logScreenView(screenName: AnalyticsEvents.screenQuran);
      FirebaseService.logEvent(name: AnalyticsEvents.quranScreenViewed);
      _scheduleOpenSurahFromWidgetTap();
    });
  }

  @override
  void dispose() {
    pendingWidgetVerseListIndex.removeListener(_onPendingWidgetVerseFromWidget);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onPendingWidgetVerseFromWidget() {
    _scheduleOpenSurahFromWidgetTap();
  }

  void _scheduleOpenSurahFromWidgetTap() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _tryOpenSurahFromWidgetListIndex());
    });
  }

  Future<void> _tryOpenSurahFromWidgetListIndex() async {
    final listIndex = pendingWidgetVerseListIndex.value;
    if (listIndex == null || !mounted) return;

    final verse =
        await QuranOfflineRepository.instance.verseAtListIndex(listIndex);
    if (!mounted) return;
    if (verse == null) {
      pendingWidgetVerseListIndex.value = null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ayet bilgisi yüklenemedi.')),
      );
      return;
    }

    pendingWidgetVerseListIndex.value = null;

    final surahName = QuranAudioService.turkishSurahNames[verse.surah] ??
        'Sure ${verse.surah}';
    final initialIdx = verse.ayahInSurah > 0 ? verse.ayahInSurah - 1 : 0;

    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => SurahDetailScreen(
          surahNumber: verse.surah,
          surahName: surahName,
          initialVerseIndex: initialIdx,
          autoPlayNextSurah: false,
          autoAdvanceVerses: false,
          autoStartPlayback: false,
        ),
      ),
    );

    FirebaseService.logEvent(
      name: 'quran_opened_from_widget',
      parameters: {
        AnalyticsParams.surahNumber: verse.surah,
      },
    );
  }

  Future<void> _loadSavedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLastRead = prefs.getInt(_keyLastRead);
      if (savedLastRead != null) {
        setState(() => _lastReadSurah = savedLastRead);
      }
    } catch (_) {}
  }

  Future<void> _saveLastReadSurah(int surahNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyLastRead, surahNumber);
      setState(() => _lastReadSurah = surahNumber);
    } catch (_) {}
  }

  void _filterSurahs(String query) {
    setState(() {
      _searchQuery = query.toLowerCase().trim();

      if (_searchQuery.isEmpty) {
        _filteredSurahs = _surahs;
      } else {
        _filteredSurahs = _surahs.where((surah) {
          // Search by surah name (Turkish)
          final nameMatch = surah.name.toLowerCase().contains(_searchQuery);

          // Search by surah number
          final numberMatch = surah.number.toString().contains(_searchQuery);

          return nameMatch || numberMatch;
        }).toList();
      }
    });
  }

  void _openSurahReader(int surahNumber, String surahName,
      {bool autoPlayNext = false}) async {
    _saveLastReadSurah(surahNumber);

    final prefs = await SharedPreferences.getInstance();
    final lastVerse = prefs.getInt('$_keyLastVerse$surahNumber') ?? 0;

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SurahDetailScreen(
          surahNumber: surahNumber,
          surahName: surahName,
          initialVerseIndex: lastVerse,
          autoPlayNextSurah: autoPlayNext,
          autoAdvanceVerses: true,
          autoStartPlayback: autoPlayNext,
        ),
      ),
    );

    FirebaseService.logEvent(
      name: 'quran_surah_opened',
      parameters: {
        AnalyticsParams.surahNumber: surahNumber,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const Icon(Icons.menu_rounded),
        title: const Text('Her Gün İslam', style: TextStyle(fontSize: 24)),
        centerTitle: true,
        actions: [
          ...WidgetShortcutHelper.appBarActions(context),
          const SizedBox(width: 6),
        ],
      ),
      body: Container(
        color: AppTheme.ivory,
        child: SafeArea(
          child: Column(
            children: [
              const AdBannerWidget(useSecondAd: true),
              Expanded(child: _buildSurahList()),
              const AdBannerWidget(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.ambientShadow,
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _filterSurahs,
        decoration: InputDecoration(
          hintText: 'Sure ara... (örn: Bakara, Yasin, 2)',
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 14,
          ),
          border: InputBorder.none,
          icon: const Icon(
            Icons.search,
            color: AppTheme.navy,
            size: 24,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: Colors.grey.shade400,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    _filterSurahs('');
                  },
                )
              : null,
        ),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _buildSurahList() {
    return RepaintBoundary(
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(child: _buildPlayAllCard()),
          // Show search results count when searching
          if (_searchQuery.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  '${_filteredSurahs.length} sure bulundu',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          // Stitch tasarımındaki tek sütun sure kartları.
          if (_filteredSurahs.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final surah = _filteredSurahs[index];
                    final isLastRead = _lastReadSurah == surah.number;
                    return _SurahGridTile(
                      surah: surah,
                      isLastRead: isLastRead,
                      onTap: () => _openSurahReader(surah.number, surah.name),
                    );
                  },
                  childCount: _filteredSurahs.length,
                ),
              ),
            ),
          if (_filteredSurahs.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search_off_rounded,
                        size: 52, color: AppTheme.outline),
                    const SizedBox(height: 12),
                    const Text('Sure bulunamadı',
                        style: TextStyle(
                            color: AppTheme.navy,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('"$_searchQuery" için sonuç yok',
                        style: const TextStyle(color: AppTheme.textMuted)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayAllCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Column(
        children: [
          if (_lastReadSurah != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.navyContainer,
                borderRadius: BorderRadius.circular(18),
                boxShadow: AppTheme.ambientShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('KALDIĞIN YERDEN',
                      style: TextStyle(
                          color: Color(0xFFA9C9F0),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .8)),
                  const SizedBox(height: 10),
                  Text(
                      QuranAudioService.turkishSurahNames[_lastReadSurah] ??
                          'Sure $_lastReadSurah',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.navy),
                    onPressed: () => _openSurahReader(
                        _lastReadSurah!,
                        QuranAudioService.turkishSurahNames[_lastReadSurah] ??
                            'Sure $_lastReadSurah'),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Devam Et'),
                  ),
                ],
              ),
            ),
          if (_lastReadSurah != null) const SizedBox(height: 14),
          _buildSearchBar(),
          if (_searchQuery.isNotEmpty) const SizedBox(height: 4),
          if (_searchQuery.isEmpty) ...[
            Row(
              children: [
                Expanded(
                    child: _QuickQuranTile(
                        icon: Icons.headphones_rounded,
                        label: 'Hatim Dinle',
                        color: AppTheme.mint,
                        onTap: _openFullQuranPlayer)),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickQuranTile(
                    icon: Icons.auto_stories_rounded,
                    label: 'Cüzler',
                    color: const Color(0xFFFFDEA3),
                    onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const JuzListScreen())),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Align(
                alignment: Alignment.centerLeft,
                child: Text('Sureler',
                    style: TextStyle(
                        color: AppTheme.navy,
                        fontSize: 22,
                        fontWeight: FontWeight.w700))),
          ],
        ],
      ),
    );
  }

  void _openFullQuranPlayer() {
    // Navigate to a special screen that plays all surahs sequentially
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hatim Dinle'),
        content: const Text(
          'Tüm Kur\'an-ı Kerim\'i baştan sona dinlemek istiyor musunuz?\n\nFatiha\'dan başlayıp Nas suresine kadar sırayla çalacaktır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openSurahReader(1, 'Fatiha',
                  autoPlayNext: true); // Start from Fatiha with auto-play
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E40AF),
            ),
            child: const Text('Başlat'),
          ),
        ],
      ),
    );
  }
}

class _QuickQuranTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickQuranTile(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 126,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.ambientShadow),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                  radius: 25,
                  backgroundColor: color,
                  child: Icon(icon, color: AppTheme.navy)),
              const SizedBox(height: 12),
              Text(label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SurahGridTile extends StatelessWidget {
  final QuranSurahInfo surah;
  final bool isLastRead;
  final VoidCallback onTap;

  const _SurahGridTile({
    required this.surah,
    this.isLastRead = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 88,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.ambientShadow),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isLastRead ? AppTheme.mint : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.gold),
                  ),
                  child: Text('${surah.number}',
                      style: const TextStyle(
                          color: AppTheme.navy, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(surah.name,
                          style: const TextStyle(
                              color: AppTheme.navy,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                                color: AppTheme.mint,
                                borderRadius: BorderRadius.circular(7)),
                            child: const Text('SURE',
                                style: TextStyle(
                                    color: AppTheme.emerald,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 8),
                          Text('${surah.number}. sure',
                              style: const TextStyle(
                                  color: AppTheme.textMuted, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isLastRead)
                  const Icon(Icons.bookmark_rounded, color: AppTheme.gold),
                const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
