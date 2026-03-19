import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' show cos, sin;
import '../models/quran_verse.dart';
import '../models/verse_timing.dart';
import '../services/quran_text_service.dart';
import '../services/quran_timing_service.dart';
import '../services/quran_audio_service.dart';
import '../services/audio_cache_service.dart';
import '../services/firebase_service.dart';
import '../widgets/quran_verse_widget.dart';

/// Interactive Quran reader screen with word-by-word highlighting
class QuranReaderScreen extends StatefulWidget {
  final int surahNumber;
  final String surahName;
  final int reciterId;
  final bool autoPlayNext; // Auto-play next surah when finished
  final int initialVerseIndex; // Resume from this verse

  const QuranReaderScreen({
    Key? key,
    required this.surahNumber,
    required this.surahName,
    this.reciterId = 7, // Default: Hani Ar Rifai
    this.autoPlayNext = false,
    this.initialVerseIndex = 0,
  }) : super(key: key);

  @override
  State<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen> {
  // Services
  final QuranTextService _textService = QuranTextService();
  final QuranTimingService _timingService = QuranTimingService();
  final QuranAudioService _audioService = QuranAudioService();
  final AudioCacheService _cacheService = AudioCacheService();
  late final AudioPlayer _audioPlayer;

  // Controllers
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _verseKeys = [];

  // Data
  List<QuranVerse> _verses = [];
  List<VerseTiming> _timings = [];
  String? _audioUrl;

  // State
  bool _isLoadingText = true;
  bool _isLoadingTimings = false;
  bool _isLoadingAudio = false;
  bool _isPlaying = false;
  int? _currentVerseIndex;
  String? _errorMessage;
  Duration? _audioDuration; // Track audio duration

  // Settings
  double _arabicFontSize = 26.0;
  double _turkishFontSize = 16.0;
  bool _autoScrollEnabled = true;
  bool _autoPageTurn = true; // Auto turn page based on audio timing
  double _volume = 0.5; // Volume control (0.0 to 1.0), default 50%

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _setupAudioPlayer();
    _loadContent();

    // Log screen view
    FirebaseService.logScreenView(
      screenName: '${AnalyticsEvents.screenQuran}_reader',
    );
    FirebaseService.logEvent(
      name: 'quran_reader_opened',
      parameters: {
        AnalyticsParams.surahNumber: widget.surahNumber,
      },
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupAudioPlayer() {
    // Set initial volume
    _audioPlayer.setVolume(_volume);
    
    // Listen to audio position for verse tracking
    _audioPlayer.onPositionChanged.listen((position) {
      if (!mounted) return;
      _updateHighlightFromPosition(position.inMilliseconds);
    });

    // Listen to duration changes
    _audioPlayer.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() {
        _audioDuration = duration;
      });
    });

    // Listen to player state
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });

    // Listen to completion
    _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _currentVerseIndex = null;
      });

      // Auto-play next surah if enabled
      if (widget.autoPlayNext && widget.surahNumber < 114) {
        _showNextSurahDialog();
      }
    });
  }

  void _showNextSurahDialog() {
    final nextSurahNumber = widget.surahNumber + 1;
    final nextSurahName = QuranAudioService.turkishSurahNames[nextSurahNumber] ?? 'Sure $nextSurahNumber';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Sure Tamamlandı'),
        content: Text(
          '${widget.surahName} suresi tamamlandı.\n\nSonraki sure: $nextSurahName\n\nDevam etmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close reader
            },
            child: const Text('Bitir'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => QuranReaderScreen(
                    surahNumber: nextSurahNumber,
                    surahName: nextSurahName,
                    reciterId: widget.reciterId,
                    autoPlayNext: true,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
            ),
            child: const Text('Devam Et'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoadingText = true;
      _errorMessage = null;
    });

    try {
      // Load verses (required)
      final verses = await _textService.fetchSurah(widget.surahNumber);
      
      if (verses.isEmpty) {
        setState(() {
          _errorMessage = 'Ayetler yüklenemedi. Lütfen tekrar deneyin.';
          _isLoadingText = false;
        });
        return;
      }

      // Create global keys for each verse (for scrolling)
      _verseKeys.clear();
      for (int i = 0; i < verses.length; i++) {
        _verseKeys.add(GlobalKey());
      }

      setState(() {
        _verses = verses;
        _isLoadingText = false;
        _currentVerseIndex = widget.initialVerseIndex.clamp(0, verses.length - 1);
      });

      // Scroll to saved verse position
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.initialVerseIndex > 0 && widget.initialVerseIndex < verses.length) {
          _scrollToVerse(widget.initialVerseIndex);
        }
      });

      // Load timings and audio in parallel for faster loading
      Future.wait([
        _loadTimings(),
        _loadAudio(),
      ]);
    } catch (e) {
      setState(() {
        _errorMessage = 'İçerik yüklenirken hata oluştu: ${e.toString()}';
        _isLoadingText = false;
      });

      FirebaseService.logError(
        exception: e,
        reason: 'Error loading Quran reader content',
      );
    }
  }

  Future<void> _loadTimings() async {
    setState(() => _isLoadingTimings = true);

    try {
      // Always try to fetch timing data from ID 7 (Hani Ar Rifai)
      // because it has the most complete word-level timing data
      final timings = await _timingService.fetchChapterTimings(
        chapterNumber: widget.surahNumber,
        reciterId: 7, // Always use ID 7 for timing
      );

      if (mounted) {
        setState(() {
          _timings = timings;
          _isLoadingTimings = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTimings = false);
      }
    }
  }

  Future<void> _loadAudio() async {
    setState(() => _isLoadingAudio = true);

    try {
      // First, check if audio is cached
      final cachedPath = await _cacheService.getCachedAudioPath(
        widget.surahNumber,
        widget.reciterId,
      );

      if (cachedPath != null) {
        // Use cached audio - instant playback!
        await _audioPlayer.setSourceDeviceFile(cachedPath);
        
        setState(() {
          _audioUrl = cachedPath;
          _isLoadingAudio = false;
        });
        return;
      }

      // Not cached, fetch URL from API
      final url = await _audioService.fetchSurahAudioUrl(
        surahNumber: widget.surahNumber,
        reciterId: widget.reciterId,
      );

      if (url != null && url.isNotEmpty) {
        setState(() {
          _audioUrl = url;
          _isLoadingAudio = false;
        });

        // Start background download for caching (don't wait for it)
        _downloadAndCacheAudio(url);
      } else {
        setState(() {
          _audioUrl = null;
          _isLoadingAudio = false;
        });
      }
    } catch (e) {
      setState(() {
        _audioUrl = null;
        _isLoadingAudio = false;
      });
    }
  }

  Future<void> _downloadAndCacheAudio(String url) async {
    try {
      // Download and cache in background (no UI updates)
      await _cacheService.downloadAndCache(
        url: url,
        surahNumber: widget.surahNumber,
        reciterId: widget.reciterId,
      );
    } catch (e) {
      // Silently fail - caching is optional
    }
  }

  void _updateHighlightFromPosition(int currentMs) {
    // If we have timing data, use it for precise highlighting
    if (_timings.isNotEmpty) {
      _updateWithTimingData(currentMs);
      return;
    }

    // If no timing data, estimate verse progression based on audio duration
    if (_audioDuration != null && _verses.isNotEmpty) {
      _updateWithEstimation(currentMs);
    }
  }

  void _updateWithTimingData(int currentMs) {
    // Find current verse based on timestamp
    final verseIndex = _timings.indexWhere((v) =>
      currentMs >= v.timestampFrom && currentMs <= v.timestampTo
    );

    if (verseIndex != -1) {
      // Update state if verse changed
      if (_currentVerseIndex != verseIndex) {
        setState(() {
          _currentVerseIndex = verseIndex;
        });

        // Save verse position
        _saveVersePosition(verseIndex);

        // Auto-scroll to current verse
        if (_autoPageTurn) {
          _scrollToVerse(verseIndex);
        }
      }
    }
  }

  void _updateWithEstimation(int currentMs) {
    final totalMs = _audioDuration!.inMilliseconds;
    
    if (totalMs <= 0) return;

    // Calculate total text length (Arabic words count as proxy for verse duration)
    int totalWords = 0;
    final verseWordCounts = <int>[];
    for (final verse in _verses) {
      final wordCount = verse.arabicWords.length;
      verseWordCounts.add(wordCount);
      totalWords += wordCount;
    }

    if (totalWords == 0) return;

    // Calculate cumulative time for each verse based on word count
    int cumulativeWords = 0;
    int estimatedVerseIndex = 0;
    
    for (int i = 0; i < _verses.length; i++) {
      cumulativeWords += verseWordCounts[i];
      final verseEndTime = (cumulativeWords / totalWords) * totalMs;
      
      if (currentMs <= verseEndTime) {
        estimatedVerseIndex = i;
        break;
      }
    }

    // Clamp to valid range
    final clampedIndex = estimatedVerseIndex.clamp(0, _verses.length - 1);

    // Update state if changed
    if (_currentVerseIndex != clampedIndex) {
      setState(() {
        _currentVerseIndex = clampedIndex;
      });

      // Save verse position when it changes
      _saveVersePosition(clampedIndex);

      // Auto-scroll to current verse
      if (_autoPageTurn) {
        _scrollToVerse(clampedIndex);
      }
    }
  }

  void _scrollToVerse(int index) {
    if (index < 0 || index >= _verses.length) return;
    if (index >= _verseKeys.length) return;

    final context = _verseKeys[index].currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.2, // Position verse near top of screen
      );
    }
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      return;
    }

    // Resume if paused
    if (_audioPlayer.state == PlayerState.paused) {
      await _audioPlayer.resume();
      return;
    }

    // Start playing
    if (_audioUrl == null || _audioUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ses dosyası yüklenemedi. İnternet bağlantınızı kontrol edin.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Audio is already preloaded, just play
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      
      // If it's a cached file, use device file source, otherwise use URL
      if (_audioUrl!.startsWith('/')) {
        // Local file path
        await _audioPlayer.play(DeviceFileSource(_audioUrl!));
      } else {
        // Remote URL
        await _audioPlayer.play(UrlSource(_audioUrl!));
      }

      FirebaseService.logEvent(
        name: AnalyticsEvents.quranSurahPlayed,
        parameters: {
          AnalyticsParams.surahNumber: widget.surahNumber,
          AnalyticsParams.reciterId: widget.reciterId,
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ses çalınamadı: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _stopPlayback() async {
    await _audioPlayer.stop();
    setState(() {
      _currentVerseIndex = null;
    });
  }

  void _goToNextSurah() {
    if (widget.surahNumber >= 114) return;

    final nextSurahNumber = widget.surahNumber + 1;
    final nextSurahName = QuranAudioService.turkishSurahNames[nextSurahNumber] ?? 'Sure $nextSurahNumber';

    // Stop current playback
    _stopPlayback();

    // Navigate to next surah
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => QuranReaderScreen(
          surahNumber: nextSurahNumber,
          surahName: nextSurahName,
          reciterId: widget.reciterId,
          autoPlayNext: widget.autoPlayNext,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildPlayerBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        '${widget.surahName} Suresi',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20,
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
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: _showSettingsDialog,
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoadingText) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFF0FDFA).withOpacity(0.3),
            const Color(0xFFCCFBF1).withOpacity(0.5),
            const Color(0xFFE0F2F1).withOpacity(0.4),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Background pattern - Islamic geometric design
          Positioned.fill(
            child: CustomPaint(
              painter: IslamicPatternPainter(),
            ),
          ),
          // Content - ListView to show multiple verses per screen
          ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: _verses.length,
            itemBuilder: (context, index) {
              final verse = _verses[index];
              final isCurrentVerse = _currentVerseIndex == index;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: QuranVerseWidget(
                  key: _verseKeys[index],
                  verse: verse,
                  isCurrentVerse: isCurrentVerse,
                  highlightedWordIndex: null, // No word highlighting
                  arabicFontSize: _arabicFontSize,
                  turkishFontSize: _turkishFontSize,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: QuranVerseSkeletonWidget(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Bir hata oluştu',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadContent,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildPlayerBar() {
    // Always show player bar, even when loading
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Loading indicator when audio is being loaded
            if (_isLoadingAudio)
              Column(
                children: [
                  const LinearProgressIndicator(
                    backgroundColor: Colors.grey,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D9488)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ses hazırlanıyor...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            // Player controls
            Row(
              children: [
                // Play/Pause button - large and prominent
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D9488).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _audioUrl == null || _isLoadingAudio ? null : _togglePlayback,
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 36,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Surah info and current verse
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.surahName} Suresi',
                        style: const TextStyle(
                          color: Color(0xFF0F766E),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (_currentVerseIndex != null)
                        Text(
                          'Ayet ${_verses[_currentVerseIndex!].numberInSurah} / ${_verses.length}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        )
                      else
                        Text(
                          _isPlaying ? 'Çalıyor...' : 'Dinlemeye hazır',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                // Stop button - only show when playing
                if (_isPlaying)
                  IconButton(
                    icon: Icon(
                      Icons.stop_rounded,
                      color: Colors.grey.shade600,
                      size: 28,
                    ),
                    onPressed: _stopPlayback,
                    tooltip: 'Durdur',
                  ),
                // Next surah button - show if not last surah
                if (widget.surahNumber < 114)
                  IconButton(
                    icon: Icon(
                      Icons.skip_next_rounded,
                      color: const Color(0xFF0D9488),
                      size: 28,
                    ),
                    onPressed: _goToNextSurah,
                    tooltip: 'Sonraki Sure',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveVersePosition(int verseIndex) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('quran_last_verse_${widget.surahNumber}', verseIndex);
    } catch (_) {}
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ayarlar'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Volume control
                  ListTile(
                    leading: Icon(
                      _volume == 0 ? Icons.volume_off : (_volume < 0.5 ? Icons.volume_down : Icons.volume_up),
                      color: const Color(0xFF0D9488),
                    ),
                    title: const Text('Ses Seviyesi'),
                    subtitle: Column(
                      children: [
                        Slider(
                          value: _volume,
                          min: 0.0,
                          max: 1.0,
                          divisions: 10,
                          label: '${(_volume * 100).round()}%',
                          onChanged: (value) {
                            setDialogState(() => _volume = value);
                            setState(() => _volume = value);
                            _audioPlayer.setVolume(value);
                          },
                        ),
                        Text(
                          '%${(_volume * 100).round()}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D9488),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  // Arabic font size
                  ListTile(
                    title: const Text('Arapça Yazı Boyutu'),
                    subtitle: Slider(
                      value: _arabicFontSize,
                      min: 20,
                      max: 36,
                      divisions: 8,
                      label: _arabicFontSize.toStringAsFixed(0),
                      onChanged: (value) {
                        setDialogState(() => _arabicFontSize = value);
                        setState(() => _arabicFontSize = value);
                      },
                    ),
                  ),
                  // Turkish font size
                  ListTile(
                    title: const Text('Türkçe Yazı Boyutu'),
                    subtitle: Slider(
                      value: _turkishFontSize,
                      min: 12,
                      max: 20,
                      divisions: 8,
                      label: _turkishFontSize.toStringAsFixed(0),
                      onChanged: (value) {
                        setDialogState(() => _turkishFontSize = value);
                        setState(() => _turkishFontSize = value);
                      },
                    ),
                  ),
                  const Divider(),
                  // Auto page turn toggle
                  SwitchListTile(
                    title: const Text('Otomatik Sayfa Geçişi'),
                    subtitle: const Text('Okunan ayete göre otomatik geç'),
                    value: _autoPageTurn,
                    onChanged: (value) {
                      setDialogState(() => _autoPageTurn = value);
                      setState(() => _autoPageTurn = value);
                    },
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for Islamic geometric background pattern
class IslamicPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0D9488).withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final fillPaint = Paint()
      ..color = const Color(0xFF14B8A6).withOpacity(0.03)
      ..style = PaintingStyle.fill;

    // Draw Islamic star pattern - more dense
    final spacing = 60.0;
    for (double x = -spacing; x < size.width + spacing; x += spacing) {
      for (double y = -spacing; y < size.height + spacing; y += spacing) {
        _drawIslamicStar(canvas, Offset(x, y), 25, paint, fillPaint);
      }
    }

    // Draw additional smaller stars in between
    final smallSpacing = spacing / 2;
    for (double x = -smallSpacing; x < size.width + smallSpacing; x += spacing) {
      for (double y = -smallSpacing; y < size.height + smallSpacing; y += spacing) {
        _drawIslamicStar(canvas, Offset(x + smallSpacing, y + smallSpacing), 15, paint, fillPaint);
      }
    }

    // Draw corner ornaments
    _drawCornerOrnament(canvas, size, paint);
    
    // Draw decorative borders
    _drawDecorativeBorders(canvas, size, paint);
  }

  void _drawIslamicStar(Canvas canvas, Offset center, double radius, Paint strokePaint, Paint fillPaint) {
    final path = Path();
    const points = 8;
    const innerRadiusRatio = 0.5;

    for (int i = 0; i < points * 2; i++) {
      final angle = (i * 3.14159 / points) - 3.14159 / 2;
      final r = i.isEven ? radius : radius * innerRadiusRatio;
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  void _drawCornerOrnament(Canvas canvas, Size size, Paint paint) {
    final ornamentPaint = Paint()
      ..color = const Color(0xFF0D9488).withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    // Top left
    _drawArc(canvas, const Offset(0, 0), 80, ornamentPaint, 0, 1.57);
    _drawArc(canvas, const Offset(0, 0), 60, ornamentPaint, 0, 1.57);
    _drawArc(canvas, const Offset(0, 0), 40, ornamentPaint, 0, 1.57);
    
    // Top right
    _drawArc(canvas, Offset(size.width, 0), 80, ornamentPaint, 1.57, 3.14);
    _drawArc(canvas, Offset(size.width, 0), 60, ornamentPaint, 1.57, 3.14);
    _drawArc(canvas, Offset(size.width, 0), 40, ornamentPaint, 1.57, 3.14);
    
    // Bottom left
    _drawArc(canvas, Offset(0, size.height), 80, ornamentPaint, 4.71, 6.28);
    _drawArc(canvas, Offset(0, size.height), 60, ornamentPaint, 4.71, 6.28);
    _drawArc(canvas, Offset(0, size.height), 40, ornamentPaint, 4.71, 6.28);
    
    // Bottom right
    _drawArc(canvas, Offset(size.width, size.height), 80, ornamentPaint, 3.14, 4.71);
    _drawArc(canvas, Offset(size.width, size.height), 60, ornamentPaint, 3.14, 4.71);
    _drawArc(canvas, Offset(size.width, size.height), 40, ornamentPaint, 3.14, 4.71);
  }

  void _drawDecorativeBorders(Canvas canvas, Size size, Paint paint) {
    final borderPaint = Paint()
      ..color = const Color(0xFF0D9488).withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Top border with pattern
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + 15, 8),
        borderPaint,
      );
      canvas.drawLine(
        Offset(x + 15, 8),
        Offset(x + 30, 0),
        borderPaint,
      );
    }

    // Bottom border with pattern
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + 15, size.height - 8),
        borderPaint,
      );
      canvas.drawLine(
        Offset(x + 15, size.height - 8),
        Offset(x + 30, size.height),
        borderPaint,
      );
    }
  }

  void _drawArc(Canvas canvas, Offset center, double radius, Paint paint, double startAngle, double endAngle) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, startAngle, endAngle - startAngle, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
