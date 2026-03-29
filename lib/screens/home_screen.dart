import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widgets_to_image/widgets_to_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/daily_item.dart';
import '../services/data_service.dart';
import '../services/ad_service.dart';
import '../services/daily_reminder_service.dart';
import '../services/notification_service.dart';
import '../services/firebase_service.dart';
import '../widgets/item_card.dart';
import '../widgets/shareable_card.dart';
import '../widgets/widget_shortcut_helper.dart';

/// Main home screen displaying the daily item
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DataService _dataService = DataService();
  final DailyReminderService _reminderService = DailyReminderService();
  final AdService _adService = AdService();
  DailyItem? _currentItem;
  bool _isLoading = true;
  bool _isSharing = false;
  bool _isRead = false;
  int _readingStreak = 0;
  String? _errorMessage;
  int _nextButtonClickCount = 0; // Sonraki buton tıklama sayacı

  @override
  void initState() {
    super.initState();
    _loadDailyItem();
    _checkReadingStatus();
    _showReminderIfNeeded();
    
    // Schedule notifications and request battery optimization exemption
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupNotificationsAndPermissions();
    });
    
    // Load interstitial ad for share feature
    _adService.loadInterstitialAd();
    
    // Load interstitial ad for next button (shown after 4 clicks)
    _adService.loadNextButtonInterstitialAd();
    
    // Log screen view to Analytics
    FirebaseService.logScreenView(screenName: AnalyticsEvents.screenHome);
  }

  /// Setup notifications and request necessary permissions
  /// Doğrudan sistem izin diyaloğu gösterilir (ara ekran yok)
  Future<void> _setupNotificationsAndPermissions() async {
    try {
      final notificationService = NotificationService();
      final prefs = await SharedPreferences.getInstance();
      const key = 'notification_permission_asked';

      final hasAskedBefore = prefs.getBool(key) ?? false;
      final hasPermission = await notificationService.areNotificationsEnabled();

      if (!mounted) return;
      if (hasPermission) {
        await notificationService.scheduleDailyReminders(context);
        return;
      }

      // İzin yok - ilk açılışta doğrudan sistem diyaloğunu göster
      if (!hasAskedBefore && mounted) {
        await prefs.setBool(key, true);
        final granted = await notificationService.requestPermission();
        if (!mounted) return;
        if (granted) {
          await notificationService.scheduleDailyReminders(context);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bildirimler açıldı. Günlük hatırlatmalar planlandı.'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        if (!mounted) return;
        await notificationService.scheduleDailyReminders(context);
      }
    } catch (e) {
      // Notifications setup failed
    }
  }
  
  /// Check if today's content is read
  Future<void> _checkReadingStatus() async {
    final hasRead = await _reminderService.hasReadToday();
    final streak = await _reminderService.getReadingStreak();
    setState(() {
      _isRead = hasRead;
      _readingStreak = streak;
    });
  }

  /// Show reminder dialog if needed
  Future<void> _showReminderIfNeeded() async {
    // Wait a bit for the UI to load
    await Future.delayed(const Duration(seconds: 1));
    
    if (!mounted) return;
    
    final shouldShow = await _reminderService.shouldShowReminder();
    if (shouldShow && _currentItem != null) {
      await _reminderService.markReminderAsShown();
      
      // Log reminder shown to Analytics
      FirebaseService.logEvent(
        name: AnalyticsEvents.reminderShown,
        parameters: {
          AnalyticsParams.itemType: _currentItem!.type,
        },
      );
      
      if (mounted) {
        _showReminderDialog();
      }
    }
  }

  /// Show reminder dialog
  void _showReminderDialog() {
    if (_currentItem == null) return;
    
    final message = _reminderService.getReminderMessage(_currentItem!.type);
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Text(
                _currentItem!.getIcon(),
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Günlük Hatırlatma',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F766E),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 16),
              if (_readingStreak > 0)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCFBF1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        color: Color(0xFFF59E0B),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$_readingStreak günlük okuma serisi! 🔥',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Daha Sonra',
                style: TextStyle(color: Color(0xFF0D9488)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _markAsRead();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
              ),
              child: const Text('Okudum'),
            ),
          ],
        );
      },
    );
  }

  /// Mark current item as read
  Future<void> _markAsRead() async {
    await _reminderService.markAsRead();
    await _checkReadingStatus();
    
    // Log reading event to Analytics
    if (_currentItem != null) {
      FirebaseService.logEvent(
        name: AnalyticsEvents.dailyItemRead,
        parameters: {
          AnalyticsParams.itemType: _currentItem!.type,
          AnalyticsParams.itemSource: _currentItem!.source,
          AnalyticsParams.readingStreak: _readingStreak,
        },
      );
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _reminderService.getStreakMessage(_readingStreak),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF14B8A6),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Load the daily item
  Future<void> _loadDailyItem({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = !forceRefresh;
      _errorMessage = null;
    });

    try {
      final item = await _dataService.getDailyItem(forceRefresh: forceRefresh);
      
      setState(() {
        _currentItem = item;
        _isLoading = false;
      });

      // Check reading status after loading item
      await _checkReadingStatus();
      
      // Show reminder if needed (only after item is loaded)
      if (item != null) {
        _showReminderIfNeeded();
        
        // Log daily item viewed to Analytics
        FirebaseService.logEvent(
          name: AnalyticsEvents.dailyItemViewed,
          parameters: {
            AnalyticsParams.itemType: item.type,
            AnalyticsParams.itemSource: item.source,
          },
        );
      }
      
      if (item == null) {
        setState(() {
          _errorMessage = 'İçerik bulunamadı. Lütfen tekrar deneyin.';
        });
      }
    } catch (e) {
      // Log error to Crashlytics
      FirebaseService.logError(
        exception: e,
        reason: 'Error loading daily item',
      );
      setState(() {
        _isLoading = false;
        _errorMessage = 'İçerik yüklenirken bir hata oluştu: ${e.toString()}';
      });
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage ?? 'Günlük içerik yüklenemedi'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Tekrar Dene',
              textColor: Colors.white,
              onPressed: () => _loadDailyItem(forceRefresh: true),
            ),
          ),
        );
      }
    }
  }

  /// Refresh data from API
  Future<void> _refreshData() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      final success = await _dataService.refreshData();
      if (success) {
        await _loadDailyItem(forceRefresh: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('İçerik başarıyla yenilendi'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'İçerik yenilenemedi. Offline mod kullanılıyor.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Yenileme sırasında hata oluştu: ${e.toString()}';
      });
    }
  }

  /// Load a random item (Next button)
  Future<void> _loadRandomItem() async {
    setState(() {
      _isLoading = true;
    });

    _nextButtonClickCount++;
    
    if (_nextButtonClickCount >= 4) {
      try {
        await _adService.showNextButtonInterstitialAd();
      } catch (e) {
        // Ad not shown
      }
      
      // Sayacı sıfırla
      _nextButtonClickCount = 0;
    }

    try {
      final item = await _dataService.getRandomItem();
      setState(() {
        _currentItem = item;
        _isLoading = false;
      });

      // Log random item viewed to Analytics
      if (item != null) {
        FirebaseService.logEvent(
          name: AnalyticsEvents.randomItemViewed,
          parameters: {
            AnalyticsParams.itemType: item.type,
            AnalyticsParams.itemSource: item.source,
          },
        );
      }
    } catch (e) {
      FirebaseService.logError(
        exception: e,
        reason: 'Error loading random item',
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Share current item as image card
  /// Reklam ve görsel oluşturma paralel çalışır - reklam bittiğinde görsel hazır olur
  Future<void> _shareItem() async {
    if (_currentItem == null) return;

    setState(() {
      _isSharing = true;
    });

    try {
      if (!mounted) return;
      final overlay = Overlay.of(context);
      late OverlayEntry overlayEntry;
      final controller = WidgetsToImageController();
      final item = _currentItem!;

      overlayEntry = OverlayEntry(
        builder: (context) => Stack(
          children: [
            Positioned(
              left: -10000,
              top: -10000,
              child: WidgetsToImage(
                controller: controller,
                child: Material(
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: ShareableCard(
                      item: item,
                      width: 1080,
                      height: 1080,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      overlay.insert(overlayEntry);

      // Paralel: görsel oluşturma (reklam sırasında arka planda hazırlanır)
      final imageFuture = Future.delayed(const Duration(milliseconds: 500))
          .then((_) => controller.capture());

      // Paralel: reklam göster (kullanıcı izler)
      final adFuture = _adService.showInterstitialAd().catchError((e) => false);

      await adFuture;
      final bytes = await imageFuture;
      if (mounted) overlayEntry.remove();

      if (bytes != null && bytes.isNotEmpty) {
        // Save image to temporary directory
        final directory = await getTemporaryDirectory();
        final imagePath = '${directory.path}/share_card_${DateTime.now().millisecondsSinceEpoch}.png';
        final imageFile = File(imagePath);
        await imageFile.writeAsBytes(bytes);

        // Share the image
        await Share.shareXFiles(
          [XFile(imagePath)],
          text: '${item.getIcon()} ${item.getTitle()}\n\nHer Gün İslam uygulamasından paylaşıldı',
          subject: '${item.getIcon()} ${item.getTitle()}',
        );

        // Log share event to Analytics
        FirebaseService.logEvent(
          name: AnalyticsEvents.dailyItemShared,
          parameters: {
            AnalyticsParams.itemType: item.type,
            AnalyticsParams.itemSource: item.source,
          },
        );

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Kart görsel olarak paylaşıldı!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

        // Clean up after sharing (optional - delete after a delay)
        Future.delayed(const Duration(minutes: 5), () {
          try {
            if (imageFile.existsSync()) {
              imageFile.deleteSync();
            }
          } catch (e) {
            // Ignore cleanup errors
          }
        });
      } else {
        _shareAsText();
      }
    } catch (e) {
      // Fallback to text sharing
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Görsel oluşturulamadı, metin olarak paylaşılıyor: $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      _shareAsText();
    } finally {
      setState(() {
        _isSharing = false;
      });
    }
  }

  /// Fallback: Share as text
  void _shareAsText() {
    if (_currentItem == null) return;

    final String shareText = '''
${_currentItem!.getIcon()} ${_currentItem!.getTitle()}

${_currentItem!.text}

— ${_currentItem!.source}

Her Gün İslam uygulamasından paylaşıldı
''';

    Share.share(shareText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // App Bar with gradient
      appBar: AppBar(
        title: Column(
          children: [
            const Text(
              'Her Gün İslam',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            if (_readingStreak > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_fire_department, color: Color(0xFFF59E0B), size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$_readingStreak gün',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
          ],
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
      
      // Body with gradient background
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
              // Upper banner ad (new position)
              const AdBannerWidget(useSecondAd: true),
              
              // Main content area
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: _isLoading
                        ? const LoadingCard()
                        : _currentItem != null
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ItemCard(
                                    item: _currentItem!,
                                    onShare: _shareItem,
                                    onNext: _loadRandomItem,
                                    onMarkAsRead: _markAsRead,
                                    isSharing: _isSharing,
                                    isRead: _isRead,
                                  ),
                                  if (!kIsWeb && Platform.isAndroid)
                                    _buildWidgetPromoCard(),
                                ],
                              )
                            : _buildErrorWidget(),
                  ),
                ),
              ),
              
              // Banner ad at the bottom
              const AdBannerWidget(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWidgetPromoCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        shadowColor: Colors.black26,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              onTap: () => WidgetShortcutHelper.offerPinWidget(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.widgets_outlined, color: Color(0xFF0D9488), size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kur\'an hatmi widget\'ı',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Fâtiha\'dan başlayıp sırayla ayet; yalnızca widget’taki ‹ › ile değişir — çevrimdışı',
                            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey[600]),
                  ],
                ),
              ),
            ),
            Divider(height: 1, thickness: 1, color: Colors.grey[200]),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.touch_app_outlined, size: 22, color: Colors.teal.shade700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Uzun ayet veya meal widget’ta tam görünmüyorsa Arapça veya meal üzerine dokunun; '
                      'Kur’an sekmesinde ilgili sure açılır ve ayete konumlanırsınız.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[800], height: 1.35),
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

  /// Error widget when no data is available
  Widget _buildErrorWidget() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'İçerik yüklenemedi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Lütfen internet bağlantınızı kontrol edin',
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => _loadDailyItem(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Tekrar Dene'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _refreshData,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Yenile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

