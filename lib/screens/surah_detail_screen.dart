import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chapter_recitation.dart';
import '../models/surah_ayah_detail.dart';
import '../models/verse_timing.dart';
import '../services/alquran_cloud_surah_service.dart';
import '../services/quran_offline_repository.dart';
import '../services/firebase_service.dart';
import '../services/quran_audio_service.dart';
import '../services/quran_timing_service.dart';
import '../widgets/surah_ayah_card.dart';
import '../widgets/surah_detail_shimmer.dart';

/// Sure detay: metin Alquran.cloud; tek parça MP3 + ayet zaman damgaları Quran.com API v4.
class SurahDetailScreen extends StatefulWidget {
  final int surahNumber;
  final String surahName;
  final int initialVerseIndex;
  final bool autoPlayNextSurah;
  final bool autoAdvanceVerses;
  final bool autoStartPlayback;

  const SurahDetailScreen({
    super.key,
    required this.surahNumber,
    required this.surahName,
    this.initialVerseIndex = 0,
    this.autoPlayNextSurah = false,
    this.autoAdvanceVerses = true,
    this.autoStartPlayback = false,
  });

  @override
  State<SurahDetailScreen> createState() => _SurahDetailScreenState();
}

class _SurahDetailScreenState extends State<SurahDetailScreen> {
  final AlquranCloudSurahService _textApi = AlquranCloudSurahService();
  final QuranTimingService _timingApi = QuranTimingService();
  final ItemScrollController _itemScrollController = ItemScrollController();
  late final AudioPlayer _player;

  /// Quran.com eşlemesi: [QuranAudioService] / eski okuyucu id → chapter_recitations.
  static const int _appReciterIdForQuranCom = 7;

  List<SurahAyahDetail> _ayahs = [];
  final Map<int, VerseTiming> _timingByVerseInSurah = {};

  List<VerseTiming> _timings = [];
  String? _audioUrl;
  bool _chapterSourceLoaded = false;

  bool _loading = true;
  String? _errorMessage;
  int? _activeAyahIndex;
  bool _isPlaying = false;
  final Set<String> _favorites = {};
  bool _didAutoStart = false;

  StreamSubscription<Duration>? _positionSub;

  static const String _prefsFavorites = 'quran_favorite_ayah_keys';
  static const String _keyLastVersePrefix = 'quran_last_verse_';

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    unawaited(_configurePlayerForStreaming());
    _bindPlayerStateAndComplete();
    _loadFavorites();
    _loadContent();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FirebaseService.logScreenView(screenName: 'quran_surah_detail');
      FirebaseService.logEvent(
        name: 'quran_surah_detail_open',
        parameters: {
          AnalyticsParams.surahNumber: widget.surahNumber,
        },
      );
    });
  }

  Future<void> _configurePlayerForStreaming() async {
    try {
      await _player.setPlayerMode(PlayerMode.mediaPlayer);
      await _player.setReleaseMode(ReleaseMode.stop);
    } catch (_) {}
  }

  void _bindPlayerStateAndComplete() {
    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state == PlayerState.playing);
    });

    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() => _isPlaying = false);
      if (widget.autoPlayNextSurah && widget.surahNumber < 114) {
        _showNextSurahDialog();
      }
    });
  }

  void _subscribePositionStream() {
    _positionSub?.cancel();
    _positionSub = _player.onPositionChanged.listen((position) {
      if (!mounted) return;
      final ms = position.inMilliseconds;
      final idx = _listIndexForPositionMs(ms);
      if (idx == null || idx == _activeAyahIndex) return;
      setState(() => _activeAyahIndex = idx);
      unawaited(_saveVerseIndex(idx));
      if (_player.state == PlayerState.playing) {
        _scrollToAyahIndex(idx);
      }
    });
  }

  VerseTiming? _timingForListIndex(int listIndex) {
    if (listIndex < 0 || listIndex >= _ayahs.length) return null;
    final n = _ayahs[listIndex].numberInSurah;
    return _timingByVerseInSurah[n];
  }

  void _rebuildTimingLookup() {
    _timingByVerseInSurah.clear();
    for (final t in _timings) {
      if (t.surahNumber == widget.surahNumber) {
        _timingByVerseInSurah[t.verseNumber] = t;
      }
    }
  }

  /// timestamp_from <= ms <= timestamp_to veya son “başlamış” ayet (boşluklarda).
  int? _listIndexForPositionMs(int ms) {
    int? exact;
    int? lastStarted;
    for (var i = 0; i < _ayahs.length; i++) {
      final t = _timingForListIndex(i);
      if (t == null) continue;
      if (ms >= t.timestampFrom && ms <= t.timestampTo) {
        exact = i;
        break;
      }
      if (ms >= t.timestampFrom) {
        lastStarted = i;
      }
    }
    if (exact != null) return exact;
    if (lastStarted != null) return lastStarted;
    return _ayahs.isEmpty ? null : 0;
  }

  bool _canPlayAyahAt(int listIndex) {
    return _audioUrl != null &&
        _audioUrl!.isNotEmpty &&
        _timingForListIndex(listIndex) != null;
  }

  Future<void> _ensureChapterSourceLoaded() async {
    if (_chapterSourceLoaded || _audioUrl == null || _audioUrl!.isEmpty) {
      return;
    }
    await _player.setSource(UrlSource(_audioUrl!));
    _chapterSourceLoaded = true;
  }

  Future<void> _loadContent() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      Future<List<SurahAyahDetail>> loadText() async {
        await QuranOfflineRepository.instance.ensureLoaded();
        final offline = await QuranOfflineRepository.instance
            .getSurahAyahsAsDetails(widget.surahNumber);
        if (offline.isNotEmpty) return offline;
        return _textApi.fetchSurahAyahs(widget.surahNumber);
      }

      final results = await Future.wait<Object?>([
        loadText(),
        _timingApi.fetchChapterRecitationWithAudio(
          chapterNumber: widget.surahNumber,
          appReciterId: _appReciterIdForQuranCom,
          useCache: true,
        ),
      ]);
      final list = results[0]! as List<SurahAyahDetail>;
      final rec = results[1] as ChapterRecitationResult?;

      if (!mounted) return;

      _timings = rec?.timings ?? [];
      _audioUrl = rec?.audioUrl;
      _chapterSourceLoaded = false;
      _rebuildTimingLookup();

      setState(() {
        _ayahs = list;
        _loading = false;
      });

      if (_audioUrl != null &&
          _audioUrl!.isNotEmpty &&
          _timings.isNotEmpty) {
        try {
          await _ensureChapterSourceLoaded();
          _subscribePositionStream();
        } catch (e, st) {
          FirebaseService.logError(
            exception: e,
            stackTrace: st,
            reason: 'surah_detail_audio_source',
          );
        }
      }

      _scrollToInitialVerse();
      final startIdx = _ayahs.isEmpty
          ? 0
          : widget.initialVerseIndex.clamp(0, _ayahs.length - 1);
      if (_ayahs.isNotEmpty) {
        setState(() => _activeAyahIndex = startIdx);
      }

      if (widget.autoStartPlayback &&
          !_didAutoStart &&
          _ayahs.isNotEmpty &&
          _canPlayAyahAt(0)) {
        _didAutoStart = true;
        await _seekAndPlayAyahIndex(0);
      }
    } catch (e, st) {
      FirebaseService.logError(
        exception: e,
        stackTrace: st,
        reason: 'surah_detail_fetch',
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = e is AlquranCloudException
            ? e.message
            : 'İçerik yüklenemedi. İnternet bağlantınızı kontrol edin.';
      });
    }
  }

  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsFavorites) ?? [];
      if (mounted) {
        setState(() {
          _favorites
            ..clear()
            ..addAll(list);
        });
      }
    } catch (_) {}
  }

  Future<void> _persistFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsFavorites, _favorites.toList());
    } catch (_) {}
  }

  Future<void> _saveVerseIndex(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_keyLastVersePrefix${widget.surahNumber}', index);
    } catch (_) {}
  }

  void _scrollToInitialVerse() {
    if (_ayahs.isEmpty) return;
    final idx = widget.initialVerseIndex.clamp(0, _ayahs.length - 1);

    void attemptScroll({int frame = 0}) {
      if (!mounted) return;
      if (!_itemScrollController.isAttached) {
        if (frame < 25) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => attemptScroll(frame: frame + 1));
        }
        return;
      }
      _itemScrollController.scrollTo(
        index: idx,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
        alignment: 0.12,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => attemptScroll());
  }

  void _scrollToAyahIndex(int index) {
    if (index < 0 || index >= _ayahs.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_itemScrollController.isAttached) return;
      _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        alignment: 0.12,
      );
    });
  }

  Future<void> _seekAndPlayAyahIndex(int index) async {
    if (!_canPlayAyahAt(index)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bu sure için ses veya zaman damgası yüklenemedi.',
            ),
            backgroundColor: Color(0xFF1E3A8A),
          ),
        );
      }
      return;
    }

    final t = _timingForListIndex(index)!;
    try {
      await _ensureChapterSourceLoaded();
      await _player.seek(Duration(milliseconds: t.timestampFrom));
      await _player.resume();
      if (!mounted) return;
      setState(() => _activeAyahIndex = index);
      await _saveVerseIndex(index);
      _scrollToAyahIndex(index);

      FirebaseService.logEvent(
        name: 'quran_ayah_audio_play',
        parameters: {
          AnalyticsParams.surahNumber: widget.surahNumber,
          'verse_in_surah': _ayahs[index].numberInSurah,
        },
      );
    } catch (e, st) {
      FirebaseService.logError(
        exception: e,
        stackTrace: st,
        reason: 'surah_detail_seek_play',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ses başlatılamadı. Bağlantıyı kontrol edin.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _onPlayPause(int index) async {
    if (!_canPlayAyahAt(index)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu ayet için zaman damgası yok veya ses hazır değil.'),
            backgroundColor: Color(0xFF1E3A8A),
          ),
        );
      }
      return;
    }

    if (_activeAyahIndex == index &&
        _player.state == PlayerState.playing) {
      await _player.pause();
      return;
    }

    if (_activeAyahIndex == index &&
        _player.state == PlayerState.paused) {
      await _player.resume();
      return;
    }

    await _seekAndPlayAyahIndex(index);
  }

  void _toggleFavorite(SurahAyahDetail a) {
    final k = a.favoriteKey(widget.surahNumber);
    setState(() {
      if (_favorites.contains(k)) {
        _favorites.remove(k);
      } else {
        _favorites.add(k);
      }
    });
    _persistFavorites();
  }

  Future<void> _copyAyah(SurahAyahDetail a) async {
    final header = '${widget.surahName} Suresi, ${a.numberInSurah}. Ayet';
    final text = '${a.shareSnippet}\n\n— $header';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Metin panoya kopyalandı.'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF1E40AF),
      ),
    );
  }

  Future<void> _shareAyah(SurahAyahDetail a) async {
    final header = '${widget.surahName} Suresi, ${a.numberInSurah}. Ayet';
    await Share.share('${a.shareSnippet}\n\n— $header');
  }

  void _showNextSurahDialog() {
    final next = widget.surahNumber + 1;
    final name =
        QuranAudioService.turkishSurahNames[next] ?? 'Sure $next';

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Sure tamamlandı'),
        content: Text(
          '${widget.surahName} suresi bitti.\n\nSonraki: $name\n\nDevam etmek ister misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Bitir'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => SurahDetailScreen(
                    surahNumber: next,
                    surahName: name,
                    initialVerseIndex: 0,
                    autoPlayNextSurah: true,
                    autoAdvanceVerses: true,
                    autoStartPlayback: true,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E40AF),
            ),
            child: const Text('Devam et'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.surahName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              'Diyanet meali · Quran.com (tek parça ses)',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const SingleChildScrollView(
                  child: SurahDetailShimmerList(itemCount: 7),
                )
              : _errorMessage != null
                  ? _buildError()
                  : _buildList(),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 72, color: Colors.grey.shade500),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.45,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _loadContent,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar dene'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E40AF),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ScrollablePositionedList.builder(
      itemCount: _ayahs.length,
      itemScrollController: _itemScrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      itemBuilder: (context, index) {
        final a = _ayahs[index];
        final hasAudio = _canPlayAyahAt(index);
        final active = _activeAyahIndex == index;
        final fav = _favorites.contains(a.favoriteKey(widget.surahNumber));

        return KeyedSubtree(
          key: ValueKey<int>(index),
          child: SurahAyahCard(
            ayah: a,
            surahName: widget.surahName,
            highlightActive: active,
            isPlaying: active && _isPlaying,
            hasAudio: hasAudio,
            isFavorite: fav,
            onPlayPause: () => _onPlayPause(index),
            onShare: () => _shareAyah(a),
            onCopy: () => _copyAyah(a),
            onFavorite: () => _toggleFavorite(a),
          ),
        );
      },
    );
  }
}
