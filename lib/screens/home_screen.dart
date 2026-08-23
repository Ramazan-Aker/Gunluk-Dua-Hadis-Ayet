import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widgets_to_image/widgets_to_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/daily_item.dart';
import '../models/daily_spiritual_plan.dart';
import '../services/data_service.dart';
import '../services/ad_service.dart';
import '../services/daily_reminder_service.dart';
import '../services/notification_service.dart';
import '../services/firebase_service.dart';
import '../widgets/item_card.dart';
import '../widgets/shareable_card.dart';
import '../models/share_format.dart';
import '../theme/app_theme.dart';
import '../models/religious_day.dart';
import '../services/religious_days_service.dart';
import '../services/quran_audio_service.dart';
import '../services/daily_spiritual_plan_service.dart';
import '../services/smart_goal_reminder_service.dart';
import '../services/achievement_service.dart';
import '../services/app_review_service.dart';
import 'daily_spiritual_plan_screen.dart';
import '../widgets/widget_shortcut_helper.dart';

/// Main home screen displaying the daily item
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onNavigateTab,
  });

  final ValueChanged<int> onNavigateTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeShortcutCard extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _HomeShortcutCard(
      {required this.eyebrow,
      required this.title,
      required this.subtitle,
      required this.icon,
      required this.accent,
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
          height: 142,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border(left: BorderSide(color: accent, width: 4)),
            boxShadow: AppTheme.ambientShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                    child: Text(eyebrow,
                        style: TextStyle(
                            color: accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .7))),
                Icon(icon, color: accent, size: 22)
              ]),
              const Spacer(),
              Text(title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppTheme.navy,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeWideCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String badge;
  final VoidCallback onTap;

  const _HomeWideCard(
      {required this.icon,
      required this.title,
      required this.value,
      required this.badge,
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
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.ambientShadow),
          child: Column(
            children: [
              Row(children: [
                Icon(icon, color: AppTheme.gold),
                const SizedBox(width: 10),
                Text(title,
                    style: const TextStyle(
                        color: AppTheme.navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w700))
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                    child: Text(value, style: const TextStyle(fontSize: 14))),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFDEA3),
                        borderRadius: BorderRadius.circular(999)),
                    child: Text(badge,
                        style: const TextStyle(
                            color: Color(0xFF7B5700), fontSize: 11)))
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _WidgetPromoOption extends StatelessWidget {
  const _WidgetPromoOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.emphasized = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: emphasized
            ? AppTheme.emerald.withValues(alpha: .38)
            : Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: emphasized
              ? AppTheme.gold.withValues(alpha: .62)
              : Colors.white.withValues(alpha: .14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.gold, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.ivory,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.mint,
              fontSize: 9,
              height: 1.2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeScreenState extends State<HomeScreen> {
  final DataService _dataService = DataService();
  final DailyReminderService _reminderService = DailyReminderService();
  final AdService _adService = AdService();
  final DailySpiritualPlanService _dailyPlanService =
      DailySpiritualPlanService();
  // iOS share sheet için paylaş butonunun konumunu takip eden key
  final GlobalKey _shareButtonKey = GlobalKey();
  DailyItem? _currentItem;
  bool _isLoading = true;
  bool _isSharing = false;
  bool _isRead = false;
  int _readingStreak = 0;
  String? _errorMessage;
  int _nextButtonClickCount = 0; // Sonraki buton tıklama sayacı
  bool _isPrivacyOptionsRequired = false;
  String _homeCityName = 'Şehir seçin';
  int? _homeLastReadSurah;
  ReligiousDay? _upcomingReligiousDay;
  DailySpiritualPlanSummary? _dailyPlan;

  @override
  void initState() {
    super.initState();
    _loadHomeShortcuts();
    _loadDailyItem();
    _checkReadingStatus();
    _showReminderIfNeeded();

    // Schedule notifications and request battery optimization exemption
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _setupNotificationsAndPermissions();
      // Önce rıza/takip izni al (ATT + UMP) — tamamlanana kadar bekle
      await AdService.requestConsentAndPermissions();
      await _updatePrivacyOptionsRequirement();
      // Consent tamamlandıktan sonra interstitial reklamları yükle
      _adService.loadInterstitialAd();
      _adService.loadNextButtonInterstitialAd();
    });

    // Log screen view to Analytics
    FirebaseService.logScreenView(screenName: AnalyticsEvents.screenHome);
  }

  Future<void> _loadHomeShortcuts() async {
    final prefs = await SharedPreferences.getInstance();
    final city = prefs.getString('ramadan_selected_city_name');
    final lastRead = prefs.getInt('quran_last_read_surah');
    final upcoming = ReligiousDaysService().getUpcomingDays();
    final dailyPlan = await _dailyPlanService.loadSummary();
    if (!mounted) return;
    setState(() {
      _homeCityName = city ?? 'Şehir seçin';
      _homeLastReadSurah = lastRead;
      _upcomingReligiousDay = upcoming.isEmpty ? null : upcoming.first;
      _dailyPlan = dailyPlan;
    });
  }

  Future<void> _updatePrivacyOptionsRequirement() async {
    final isRequired = await AdService.isPrivacyOptionsRequired();
    if (mounted) {
      setState(() => _isPrivacyOptionsRequired = isRequired);
    }
  }

  Future<void> _showPrivacyOptions() async {
    final error = await AdService.showPrivacyOptionsForm();
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gizlilik seçenekleri açılamadı: ${error.message}'),
        ),
      );
    }
    await _updatePrivacyOptionsRequirement();
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
                content:
                    Text('Bildirimler açıldı. Günlük hatırlatmalar planlandı.'),
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
                    color: Color(0xFF1E3A8A),
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
                    color: const Color(0xFFDBEAFE),
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
                            color: Color(0xFF1E3A8A),
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
                style: TextStyle(color: Color(0xFF1E40AF)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _markAsRead();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E40AF),
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
    await _reloadDailyPlan();
    unawaited(SmartGoalReminderService().refreshSchedule());
    unawaited(AchievementService().evaluateAndUnlock(notify: true));

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
          backgroundColor: const Color(0xFFF59E0B),
          duration: const Duration(seconds: 3),
        ),
      );
      unawaited(
        Future<void>.delayed(const Duration(seconds: 2), () async {
          await AppReviewService().registerMeaningfulActionAndMaybeRequest();
        }),
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
    final format = await _chooseShareFormat();
    if (format == null) return;

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
                      width: format.width,
                      height: format.height,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      overlay.insert(overlayEntry);

      // Paralel: görsel oluşturma (reklam sırasında arka planda hazırlanır).
      // Overlay'in ilk karesi çizilmeden yakalama yapılırsa iOS'ta widget
      // context'i null kalabildiği için önce render tamamlanmasını bekleriz.
      final imageFuture = () async {
        await WidgetsBinding.instance.endOfFrame;
        return controller.capture();
      }();

      // Paralel: reklam göster (kullanıcı izler)
      final adFuture = _adService.showInterstitialAd().catchError((e) => false);

      await adFuture;
      Uint8List? bytes;
      try {
        bytes = await imageFuture;
      } finally {
        if (overlayEntry.mounted) overlayEntry.remove();
      }

      if (bytes != null && bytes.isNotEmpty) {
        // Save image to temporary directory
        final directory = await getTemporaryDirectory();
        final imagePath =
            '${directory.path}/share_card_${format.name}_${DateTime.now().millisecondsSinceEpoch}.png';
        final imageFile = File(imagePath);
        await imageFile.writeAsBytes(bytes, flush: true);

        // Share the image
        // iOS'ta share sheet'in konumunu belirtmek zorunlu (iPad + iPhone uyumu)
        final box =
            _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
        final origin = box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : Rect.fromCenter(
                center: MediaQuery.of(context).size.center(Offset.zero),
                width: 1,
                height: 1,
              );

        await Share.shareXFiles(
          [XFile(imagePath, mimeType: 'image/png')],
          text:
              '${item.getIcon()} ${item.getTitle()}\n\nHer Gün İslam uygulamasından paylaşıldı',
          subject: '${item.getIcon()} ${item.getTitle()}',
          sharePositionOrigin: origin,
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
            content:
                Text('Görsel oluşturulamadı, metin olarak paylaşılıyor: $e'),
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

  Future<ShareFormat?> _chooseShareFormat() {
    return showModalBottomSheet<ShareFormat>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Paylaşım biçimi',
                  style: TextStyle(
                      color: AppTheme.navy,
                      fontSize: 21,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text(
                  'Instagram’da kırpılmaması için kullanacağınız alanı seçin.',
                  style: TextStyle(color: AppTheme.textMuted)),
              const SizedBox(height: 14),
              ...ShareFormat.values.map(
                (format) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: AspectRatio(
                    aspectRatio: format.aspectRatio,
                    child: Container(
                        decoration: BoxDecoration(
                            color: AppTheme.surfaceLow,
                            border: Border.all(color: AppTheme.navy),
                            borderRadius: BorderRadius.circular(5))),
                  ),
                  title: Text(format.label),
                  subtitle: Text(
                      '${format.width.toInt()} × ${format.height.toInt()}'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pop(context, format),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

    // iOS'ta share sheet konumu zorunlu
    final box =
        _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.fromCenter(
            center: MediaQuery.of(context).size.center(Offset.zero),
            width: 1,
            height: 1,
          );

    Share.share(shareText, sharePositionOrigin: origin);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 20,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hayırlı Günler',
                style: TextStyle(
                    color: AppTheme.navy,
                    fontSize: 22,
                    fontWeight: FontWeight.w600)),
            Text(_todayLabel(),
                style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          if (_isPrivacyOptionsRequired)
            IconButton(
              tooltip: 'Gizlilik seçenekleri',
              icon:
                  const Icon(Icons.privacy_tip_outlined, color: AppTheme.navy),
              onPressed: _showPrivacyOptions,
            ),
          ...WidgetShortcutHelper.appBarActions(context),
        ],
      ),
      body: Container(
        color: AppTheme.ivory,
        child: SafeArea(
          child: Column(
            children: [
              const AdBannerWidget(useSecondAd: true),
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
                                    shareButtonKey: _shareButtonKey,
                                  ),
                                  _buildDailyPlanShortcut(),
                                  _buildHomeShortcuts(),
                                  if (!kIsWeb &&
                                      (Platform.isAndroid || Platform.isIOS))
                                    _buildWidgetPromoCard(),
                                ],
                              )
                            : _buildErrorWidget(),
                  ),
                ),
              ),
              const AdBannerWidget(),
            ],
          ),
        ),
      ),
    );
  }

  String _todayLabel() {
    final now = DateTime.now();
    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık'
    ];
    const weekdays = [
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi',
      'Pazar'
    ];
    return '${now.day} ${months[now.month - 1]} ${weekdays[now.weekday - 1]}';
  }

  Widget _buildHomeShortcuts() {
    final surahName = _homeLastReadSurah == null
        ? 'Kur\'an okumaya başla'
        : '${QuranAudioService.turkishSurahNames[_homeLastReadSurah] ?? 'Sure'} Suresi';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _HomeShortcutCard(
                  eyebrow: 'SIRADAKİ NAMAZ',
                  title: 'Namaz Vakitleri',
                  subtitle: _homeCityName,
                  icon: Icons.mosque_outlined,
                  accent: AppTheme.emerald,
                  onTap: () => widget.onNavigateTab(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HomeShortcutCard(
                  eyebrow: 'KALDIĞIN YER',
                  title: surahName,
                  subtitle: _homeLastReadSurah == null
                      ? 'Sureler ve cüzler'
                      : 'Okumaya devam et',
                  icon: Icons.auto_stories_outlined,
                  accent: AppTheme.navy,
                  onTap: () => widget.onNavigateTab(1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_upcomingReligiousDay != null)
            _HomeWideCard(
              icon: Icons.calendar_month_outlined,
              title: 'Yaklaşan Gün',
              value: _upcomingReligiousDay!.name,
              badge: _upcomingReligiousDay!.countdownText,
              onTap: () => widget.onNavigateTab(4),
            ),
        ],
      ),
    );
  }

  Future<void> _reloadDailyPlan() async {
    final summary = await _dailyPlanService.loadSummary();
    if (mounted) setState(() => _dailyPlan = summary);
  }

  Future<void> _openDailyPlan() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const DailySpiritualPlanScreen(),
      ),
    );
    await _reloadDailyPlan();
  }

  Widget _buildDailyPlanShortcut() {
    final summary = _dailyPlan;
    final progress = summary?.progress ?? 0;
    final completed = summary?.completedCount ?? 0;
    final total = summary?.tasks.length ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Material(
        color: AppTheme.navy,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _openDailyPlan,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 50,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.square(
                        dimension: 46,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 5,
                          backgroundColor: Colors.white.withValues(alpha: .16),
                          color: AppTheme.gold,
                        ),
                      ),
                      const Icon(Icons.checklist_rounded,
                          color: Colors.white, size: 21),
                    ],
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Günlük Manevi Plan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        summary == null
                            ? 'Plan hazırlanıyor...'
                            : summary.completed
                                ? 'Bugünkü plan tamamlandı ✨'
                                : '$completed/$total hedef tamamlandı',
                        style: const TextStyle(
                          color: Color(0xFFD0E4FF),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (summary != null && summary.currentStreak > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withValues(alpha: .42),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '🔥 ${summary.currentStreak}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  const Icon(Icons.arrow_forward_rounded, color: AppTheme.gold),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWidgetPromoCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.navy, AppTheme.navyContainer],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.gold.withValues(alpha: .55)),
          boxShadow: AppTheme.ambientShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => WidgetShortcutHelper.offerPinWidget(context),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.emerald.withValues(alpha: .34),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.gold.withValues(alpha: .72),
                          ),
                        ),
                        child: const Icon(
                          Icons.widgets_rounded,
                          color: AppTheme.gold,
                          size: 23,
                        ),
                      ),
                      const SizedBox(width: 13),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ana ekran widget’ları',
                              style: TextStyle(
                                color: AppTheme.ivory,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Ana ekranında görmek istediğini seç',
                              style: TextStyle(
                                color: AppTheme.mint,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.add_circle_outline_rounded,
                        color: AppTheme.gold,
                        size: 24,
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  const Row(
                    children: [
                      Expanded(
                        child: _WidgetPromoOption(
                          icon: Icons.mosque_rounded,
                          title: 'Namaz Vakitleri',
                          subtitle: 'Sıradaki vakit ve geri sayım',
                          emphasized: true,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _WidgetPromoOption(
                          icon: Icons.auto_stories_rounded,
                          title: 'Günün Ayeti',
                          subtitle: 'Gün içinde yenilenen ayet',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
                  backgroundColor: const Color(0xFF1E40AF),
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
