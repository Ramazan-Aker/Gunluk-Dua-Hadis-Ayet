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

/// Main home screen displaying the daily item
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DataService _dataService = DataService();
  final DailyReminderService _reminderService = DailyReminderService();
  final AdService _adService = AdService();
  DailyItem? _currentItem;
  bool _isLoading = true;
  bool _isRefreshing = false;
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
  /// Shows value proposition dialog on first launch for better opt-in rate
  Future<void> _setupNotificationsAndPermissions() async {
    try {
      final notificationService = NotificationService();
      final prefs = await SharedPreferences.getInstance();
      const key = 'notification_prompt_shown';

      // Check if we need to show the value proposition dialog (first launch)
      final hasShownPrompt = prefs.getBool(key) ?? false;
      final hasPermission = await notificationService.areNotificationsEnabled();

      if (!hasShownPrompt && !hasPermission && mounted) {
        // Show friendly dialog explaining why notifications help
        final shouldRequest = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.notifications_active, color: Color(0xFF0D9488), size: 28),
                SizedBox(width: 12),
                Text('Bildirimler', style: TextStyle(fontSize: 20)),
              ],
            ),
            content: const Text(
              'Günlük duayı, hadisi veya ayeti kaçırmamak için bildirimlere izin verin.\n\n'
              '🌅 Sabah 09:00\n'
              '📖 Öğle 12:00\n'
              '🌙 Akşam 18:00\n\n'
              'Her gün 3 kez hatırlatma alacaksınız.',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Daha Sonra'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
                child: const Text('Bildirimleri Aç'),
              ),
            ],
          ),
        );
        await prefs.setBool(key, true);

        if (shouldRequest == true) {
          final granted = await notificationService.requestPermission();
          if (granted) {
            await notificationService.scheduleDailyReminders(context);
            print('✅ Daily reminders scheduled');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bildirimler açıldı. Sabah ve akşam hatırlatma alacaksınız.'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        }
      } else {
        // Already asked or has permission - just schedule
        await notificationService.scheduleDailyReminders(context);
        if (hasPermission) {
          print('✅ Daily reminders scheduled');
        }
      }
    } catch (e) {
      print('❌ Error setting up notifications: $e');
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
                          '${_readingStreak} günlük okuma serisi! 🔥',
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
      _isRefreshing = forceRefresh;
      _errorMessage = null;
    });

    try {
      final item = await _dataService.getDailyItem(forceRefresh: forceRefresh);
      
      setState(() {
        _currentItem = item;
        _isLoading = false;
        _isRefreshing = false;
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
      print('Error loading daily item: $e');
      // Log error to Crashlytics
      FirebaseService.logError(
        exception: e,
        reason: 'Error loading daily item',
      );
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
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
      _isRefreshing = true;
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
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  /// Load a random item (Next button)
  Future<void> _loadRandomItem() async {
    setState(() {
      _isLoading = true;
    });

    // Sayacı artır
    _nextButtonClickCount++;
    print('🔢 Sonraki butonu tıklama sayısı: $_nextButtonClickCount');
    
    // Her 4 tıklamada bir interstitial reklam göster (Sonraki butonu reklamı)
    if (_nextButtonClickCount >= 4) {
      print('🎯 4 tıklama tamamlandı, sonraki butonu reklamı gösteriliyor...');
      
      try {
        final adShown = await _adService.showNextButtonInterstitialAd();
        if (adShown) {
          print('✅ Sonraki butonu reklamı gösterildi ve kapatıldı');
        } else {
          print('⚠️ Sonraki butonu reklamı hazır değil');
        }
      } catch (e) {
        print('❌ Sonraki butonu reklamı gösterilirken hata: $e');
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
      print('Error loading random item: $e');
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
  Future<void> _shareItem() async {
    if (_currentItem == null) return;

    setState(() {
      _isSharing = true;
    });

    // Show interstitial ad before sharing
    // Note: showInterstitialAd() now waits for ad to be dismissed before returning
    try {
      final adShown = await _adService.showInterstitialAd();
      if (adShown) {
        print('✅ Interstitial ad shown and dismissed, continuing with share');
      } else {
        print('⚠️ Interstitial ad not ready, proceeding with share');
      }
    } catch (e) {
      print('❌ Error showing interstitial ad: $e');
      // Continue with share even if ad fails
    }

    try {
      // Yükleme göstergesi sadece Paylaş butonunda (Oluşturuluyor...) - SnackBar yok

      // Show overlay with shareable card
      if (!mounted) return;
      
      final overlay = Overlay.of(context);
      late OverlayEntry overlayEntry;
      
      final controller = WidgetsToImageController();
      
      overlayEntry = OverlayEntry(
        builder: (context) => Stack(
          children: [
            Positioned(
              left: -10000, // Off-screen
              top: -10000,
              child: WidgetsToImage(
                controller: controller,
                child: Material(
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: ShareableCard(
                      item: _currentItem!,
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
      
      // Wait for widget to render
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Capture the image
      final bytes = await controller.capture();
      
      // Remove overlay
      overlayEntry.remove();

      if (bytes != null && bytes.isNotEmpty) {
        // Save image to temporary directory
        final directory = await getTemporaryDirectory();
        final imagePath = '${directory.path}/share_card_${DateTime.now().millisecondsSinceEpoch}.png';
        final imageFile = File(imagePath);
        await imageFile.writeAsBytes(bytes);

        // Share the image
        await Share.shareXFiles(
          [XFile(imagePath)],
          text: '${_currentItem!.getTitle()}\n\nGünlük Dua & Hadis Uygulamasından paylaşıldı',
          subject: _currentItem!.getTitle(),
        );

        // Log share event to Analytics
        FirebaseService.logEvent(
          name: AnalyticsEvents.dailyItemShared,
          parameters: {
            AnalyticsParams.itemType: _currentItem!.type,
            AnalyticsParams.itemSource: _currentItem!.source,
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
        // Fallback to text sharing if image creation fails
        print('⚠️ Image is null or empty, falling back to text sharing');
        _shareAsText();
      }
    } catch (e) {
      print('❌ Error sharing image: $e');
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
${_currentItem!.getTitle()}

${_currentItem!.text}

— ${_currentItem!.source}

Günlük Dua & Hadis Uygulamasından paylaşıldı
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
              'Günlük Dua & Hadis',
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
                            ? ItemCard(
                                item: _currentItem!,
                                onShare: _shareItem,
                                onNext: _loadRandomItem,
                                onMarkAsRead: _markAsRead,
                                isSharing: _isSharing,
                                isRead: _isRead,
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

