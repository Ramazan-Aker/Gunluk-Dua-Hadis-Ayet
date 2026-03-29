import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/quran_audio_service.dart';
import '../services/ad_service.dart';
import '../services/firebase_service.dart' show FirebaseService, AnalyticsEvents, AnalyticsParams;
import '../services/quran_offline_repository.dart';
import '../widgets/widget_shortcut_helper.dart';
import '../widget_verse_pending.dart';
import 'surah_detail_screen.dart';

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
  static const String _keyLastVerse = 'quran_last_verse_'; // Prefix for verse position per surah

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
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryOpenSurahFromWidgetListIndex());
    });
  }

  Future<void> _tryOpenSurahFromWidgetListIndex() async {
    final listIndex = pendingWidgetVerseListIndex.value;
    if (listIndex == null || !mounted) return;

    final verse = await QuranOfflineRepository.instance.verseAtListIndex(listIndex);
    if (!mounted) return;
    if (verse == null) {
      pendingWidgetVerseListIndex.value = null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ayet bilgisi yüklenemedi.')),
      );
      return;
    }

    pendingWidgetVerseListIndex.value = null;

    final surahName =
        QuranAudioService.turkishSurahNames[verse.surah] ?? 'Sure ${verse.surah}';
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

  void _openSurahReader(int surahNumber, String surahName, {bool autoPlayNext = false}) async {
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
        title: const Text(
          'Kur\'an-ı Kerim',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: WidgetShortcutHelper.appBarActions(context),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF0FDFA), Color(0xFFCCFBF1)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const AdBannerWidget(useSecondAd: true),
              _buildSearchBar(),
              Expanded(
                child: _buildSurahList(),
              ),
              const AdBannerWidget(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
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
            color: Color(0xFF0D9488),
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
    // Show "no results" message if filter resulted in empty list
    if (_filteredSurahs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Sure bulunamadı',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '"$_searchQuery" için sonuç yok',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Special "Play All" card at the top (only when not searching)
          if (_searchQuery.isEmpty)
            SliverToBoxAdapter(
              child: _buildPlayAllCard(),
            ),
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
          // Grid of surahs
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
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
        ],
      ),
    );
  }

  Widget _buildPlayAllCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F766E),
            Color(0xFF0D9488),
            Color(0xFF14B8A6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openFullQuranPlayer(),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                // Large play icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_circle_filled,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 20),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hatim Dinle',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Baştan sona 114 sure',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                // Arrow icon
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withOpacity(0.8),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
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
              _openSurahReader(1, 'Fatiha', autoPlayNext: true); // Start from Fatiha with auto-play
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
            ),
            child: const Text('Başlat'),
          ),
        ],
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0D9488),
              const Color(0xFF14B8A6).withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D9488).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background pattern
            Positioned(
              right: -20,
              bottom: -20,
              child: Icon(
                Icons.menu_book_outlined,
                size: 80,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Surah number badge
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${surah.number}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      // Last read badge
                      if (isLastRead)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.bookmark,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                  // Surah name
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        surah.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sure ${surah.number}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
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
