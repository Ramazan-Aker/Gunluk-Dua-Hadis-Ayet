import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';

/// Service class to handle Google AdMob banner and interstitial ads
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  /// Reklamlar aktif
  static const bool _adsEnabled = true;
  static const String _androidTestBannerAdUnitId =
      'ca-app-pub-3940256099942544/9214589741';
  static const String _iosTestBannerAdUnitId =
      'ca-app-pub-3940256099942544/2435281174';
  static const String _androidTestInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _iosTestInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/4411468910';

  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;
  int _bannerFailedAttempts = 0;
  Timer? _bannerRetryTimer;
  DateTime? _lastBannerRequestAt;

  BannerAd? _bannerAd2;
  bool _isBannerAd2Ready = false;
  int _banner2FailedAttempts = 0;
  Timer? _banner2RetryTimer;
  DateTime? _lastBanner2RequestAt;

  /// Banner reklam basarisiz oldugunda kullanilan artan bekleme suresi.
  /// AdMob, ard arda hizli tekrar denemeleri "invalid traffic" olarak
  /// isaretleyip reklam birimini daha da az doldurabilir; bu yuzden
  /// sabit 3sn yerine ustel geri cekilme (exponential backoff) kullaniyoruz.
  static const int maxBannerFailedLoadAttempts = 3;
  static const Duration _minimumBannerRequestInterval = Duration(seconds: 60);

  static Duration _bannerRetryDelay(int attempt) {
    final seconds = 60 * (1 << attempt.clamp(0, 2)); // 60, 120, 240
    return Duration(seconds: seconds);
  }

  static Duration _remainingBannerCooldown(DateTime? lastRequestAt) {
    if (lastRequestAt == null) return Duration.zero;
    final elapsed = DateTime.now().difference(lastRequestAt);
    if (elapsed >= _minimumBannerRequestInterval) return Duration.zero;
    return _minimumBannerRequestInterval - elapsed;
  }

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;
  bool _isInterstitialAdLoading = false;
  Timer? _interstitialRetryTimer;
  int _numInterstitialLoadAttempts = 0;
  static const int maxFailedLoadAttempts = 3;
  Completer<void>? _adDismissedCompleter;

  InterstitialAd? _nextButtonInterstitialAd;
  bool _isNextButtonInterstitialAdReady = false;
  bool _isNextButtonInterstitialAdLoading = false;
  Timer? _nextButtonInterstitialRetryTimer;
  int _numNextButtonInterstitialLoadAttempts = 0;
  Completer<void>? _nextButtonAdDismissedCompleter;

  // Consent durumu
  static bool _consentChecked = false;
  static bool _consentCompleted = false;
  static bool _canRequestAds = false;
  static final List<Completer<void>> _consentWaiters = [];

  /// Request iOS Tracking (ATT) & Google UMP Consent
  /// Bu metod tamamlanmadan reklam yüklenmemeli.
  static Future<void> requestConsentAndPermissions() async {
    if (!_adsEnabled) return;

    // Eğer zaten tamamlandıysa hemen dön
    if (_consentCompleted) return;

    // Eğer zaten yürütülüyorsa, tamamlanmasını bekle
    if (_consentChecked) {
      final completer = Completer<void>();
      _consentWaiters.add(completer);
      return completer.future;
    }

    _consentChecked = true;

    try {
      // 1. iOS için App Tracking Transparency (ATT) İzni
      if (Platform.isIOS) {
        try {
          final status =
              await AppTrackingTransparency.trackingAuthorizationStatus;
          if (status == TrackingStatus.notDetermined) {
            // Splash/animasyon bitmesi için kısa bekleme
            await Future.delayed(const Duration(milliseconds: 800));
            await AppTrackingTransparency.requestTrackingAuthorization();
          }
        } catch (e) {
          debugPrint('ATT error: $e');
        }
      }

      // 2. Google UMP (User Messaging Platform) Consent
      await _requestUmpConsent();
    } catch (e) {
      debugPrint('Consent error: $e');
    } finally {
      try {
        _canRequestAds = await ConsentInformation.instance.canRequestAds();
      } catch (e) {
        _canRequestAds = false;
        debugPrint('canRequestAds error: $e');
      }
      _consentCompleted = true;
      // Bekleyen tüm completer'ları tamamla
      for (final c in _consentWaiters) {
        if (!c.isCompleted) c.complete();
      }
      _consentWaiters.clear();
    }
  }

  static Future<void> _requestUmpConsent() async {
    final completer = Completer<void>();

    try {
      final params = ConsentRequestParameters();
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          // Consent bilgisi güncellendi
          try {
            if (await ConsentInformation.instance.isConsentFormAvailable()) {
              await _loadAndShowConsentFormIfRequired();
            }
          } catch (e) {
            debugPrint('Consent form error: $e');
          }
          if (!completer.isCompleted) completer.complete();
        },
        (FormError error) {
          debugPrint('UMP requestConsentInfoUpdate error: $error');
          if (!completer.isCompleted) completer.complete();
        },
      );
    } catch (e) {
      debugPrint('UMP init error: $e');
      if (!completer.isCompleted) completer.complete();
    }

    await completer.future;
  }

  static Future<void> _loadAndShowConsentFormIfRequired() async {
    final completer = Completer<void>();
    ConsentForm.loadAndShowConsentFormIfRequired(
      (FormError? error) {
        if (error != null) {
          debugPrint('Consent form show error: $error');
        }
        if (!completer.isCompleted) completer.complete();
      },
    );
    await completer.future;
  }

  static bool get canRequestAds => _adsEnabled && _canRequestAds;

  static Future<bool> isPrivacyOptionsRequired() async {
    try {
      return await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (e) {
      debugPrint('Privacy options status error: $e');
      return false;
    }
  }

  static Future<FormError?> showPrivacyOptionsForm() async {
    final completer = Completer<FormError?>();
    ConsentForm.showPrivacyOptionsForm((error) {
      if (!completer.isCompleted) completer.complete(error);
    });
    final error = await completer.future;
    try {
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
    } catch (e) {
      _canRequestAds = false;
      debugPrint('canRequestAds after privacy options error: $e');
    }
    if (!_canRequestAds) {
      AdService().dispose();
    }
    return error;
  }

  /// Initialize AdMob
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  /// Banner Ad Unit ID - Ana Sayfa Alt Banner
  String get bannerAdUnitId {
    if (!kReleaseMode) {
      return Platform.isAndroid
          ? _androidTestBannerAdUnitId
          : _iosTestBannerAdUnitId;
    }
    if (Platform.isAndroid) {
      return 'ca-app-pub-9132542494292379/9084351705';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-9132542494292379/8967228449';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  /// Interstitial Ad Unit ID - Paylaşım Öncesi
  String get interstitialAdUnitId {
    if (!kReleaseMode) {
      return Platform.isAndroid
          ? _androidTestInterstitialAdUnitId
          : _iosTestInterstitialAdUnitId;
    }
    if (Platform.isAndroid) {
      return 'ca-app-pub-9132542494292379/8757048647';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-9132542494292379/2577079916';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  /// Next Button Interstitial Ad Unit ID - Sonraki Butonu
  String get nextButtonInterstitialAdUnitId {
    if (!kReleaseMode) {
      return Platform.isAndroid
          ? _androidTestInterstitialAdUnitId
          : _iosTestInterstitialAdUnitId;
    }
    if (Platform.isAndroid) {
      return 'ca-app-pub-9132542494292379/7443966973';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-9132542494292379/2677152264';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  /// Second Banner Ad Unit ID - Üst Banner
  String get bannerAd2UnitId {
    if (!kReleaseMode) {
      return Platform.isAndroid
          ? _androidTestBannerAdUnitId
          : _iosTestBannerAdUnitId;
    }
    if (Platform.isAndroid) {
      return 'ca-app-pub-9132542494292379/5145106696';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-9132542494292379/9398353140';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  // ─── Banner Ad 1 ───────────────────────────────────────────────────────────

  /// Load banner ad — consent tamamlandıktan sonra çağrılmalı
  void loadBannerAd({
    AdSize size = AdSize.banner,
    VoidCallback? onLoaded,
  }) {
    if (!canRequestAds) return;
    if (_bannerAd != null) {
      // Zaten yüklü ya da yükleniyor
      if (_isBannerAdReady) onLoaded?.call();
      return;
    }

    if (_bannerRetryTimer?.isActive ?? false) return;
    final cooldown = _remainingBannerCooldown(_lastBannerRequestAt);
    if (cooldown > Duration.zero) {
      _bannerRetryTimer = Timer(
        cooldown,
        () {
          _bannerRetryTimer = null;
          loadBannerAd(size: size, onLoaded: onLoaded);
        },
      );
      return;
    }

    _lastBannerRequestAt = DateTime.now();
    _bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('BannerAd 1 loaded.');
          _isBannerAdReady = true;
          _bannerFailedAttempts = 0;
          onLoaded?.call();
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd 1 failed to load: $error');
          _isBannerAdReady = false;
          ad.dispose();
          _bannerAd = null;
          _bannerFailedAttempts++;
          if (_bannerFailedAttempts <= maxBannerFailedLoadAttempts) {
            final delay = _bannerRetryDelay(_bannerFailedAttempts - 1);
            _bannerRetryTimer = Timer(delay, () {
              _bannerRetryTimer = null;
              loadBannerAd(size: size, onLoaded: onLoaded);
            });
          }
        },
        onAdOpened: (ad) {},
        onAdClosed: (ad) {},
      ),
    );

    _bannerAd?.load();
  }

  BannerAd? get bannerAd => _bannerAd;
  bool get isBannerAdReady => _adsEnabled && _isBannerAdReady;

  void disposeBannerAd() {
    _bannerRetryTimer?.cancel();
    _bannerRetryTimer = null;
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerAdReady = false;
    _bannerFailedAttempts = 0;
  }

  // ─── Banner Ad 2 ───────────────────────────────────────────────────────────

  /// Load second banner ad — consent tamamlandıktan sonra çağrılmalı
  void loadBannerAd2({
    AdSize size = AdSize.banner,
    VoidCallback? onLoaded,
  }) {
    if (!canRequestAds) return;
    if (_bannerAd2 != null) {
      if (_isBannerAd2Ready) onLoaded?.call();
      return;
    }

    if (_banner2RetryTimer?.isActive ?? false) return;
    final cooldown = _remainingBannerCooldown(_lastBanner2RequestAt);
    if (cooldown > Duration.zero) {
      _banner2RetryTimer = Timer(
        cooldown,
        () {
          _banner2RetryTimer = null;
          loadBannerAd2(size: size, onLoaded: onLoaded);
        },
      );
      return;
    }

    _lastBanner2RequestAt = DateTime.now();
    _bannerAd2 = BannerAd(
      adUnitId: bannerAd2UnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('BannerAd 2 loaded.');
          _isBannerAd2Ready = true;
          _banner2FailedAttempts = 0;
          onLoaded?.call();
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd 2 failed to load: $error');
          _isBannerAd2Ready = false;
          ad.dispose();
          _bannerAd2 = null;
          _banner2FailedAttempts++;
          if (_banner2FailedAttempts <= maxBannerFailedLoadAttempts) {
            final delay = _bannerRetryDelay(_banner2FailedAttempts - 1);
            _banner2RetryTimer = Timer(delay, () {
              _banner2RetryTimer = null;
              loadBannerAd2(size: size, onLoaded: onLoaded);
            });
          }
        },
        onAdOpened: (ad) {},
        onAdClosed: (ad) {},
      ),
    );

    _bannerAd2?.load();
  }

  BannerAd? get bannerAd2 => _bannerAd2;
  bool get isBannerAd2Ready => _adsEnabled && _isBannerAd2Ready;

  void disposeBannerAd2() {
    _banner2RetryTimer?.cancel();
    _banner2RetryTimer = null;
    _bannerAd2?.dispose();
    _bannerAd2 = null;
    _isBannerAd2Ready = false;
    _banner2FailedAttempts = 0;
  }

  // ─── Interstitial Ad (Paylaşım) ────────────────────────────────────────────

  Future<void> loadInterstitialAd() async {
    if (!_adsEnabled) return;
    if (_isInterstitialAdLoading ||
        _interstitialAd != null ||
        (_interstitialRetryTimer?.isActive ?? false)) {
      return;
    }

    // Consent tamamlanmamışsa bekle
    if (!_consentCompleted) {
      await requestConsentAndPermissions();
    }
    if (!canRequestAds || _isInterstitialAdLoading || _interstitialAd != null) {
      return;
    }

    _isInterstitialAdLoading = true;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          debugPrint('Interstitial Ad loaded.');
          _isInterstitialAdLoading = false;
          _interstitialRetryTimer?.cancel();
          _interstitialRetryTimer = null;
          if (!canRequestAds) {
            ad.dispose();
            return;
          }
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          _numInterstitialLoadAttempts = 0;
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('Interstitial Ad failed to load: $error');
          _isInterstitialAdLoading = false;
          _numInterstitialLoadAttempts += 1;
          _interstitialAd = null;
          _isInterstitialAdReady = false;

          if (_numInterstitialLoadAttempts < maxFailedLoadAttempts) {
            _interstitialRetryTimer = Timer(
              Duration(seconds: _numInterstitialLoadAttempts * 3),
              () {
                _interstitialRetryTimer = null;
                loadInterstitialAd();
              },
            );
          }
        },
      ),
    );
  }

  /// Show interstitial ad — returns true if shown
  Future<bool> showInterstitialAd() async {
    if (!_adsEnabled) return false;
    if (!_isInterstitialAdReady || _interstitialAd == null) {
      loadInterstitialAd();
      return false;
    }

    final ad = _interstitialAd!;
    _interstitialAd = null;
    _isInterstitialAdReady = false;

    try {
      _adDismissedCompleter = Completer<void>();

      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (InterstitialAd ad) {
          debugPrint('Interstitial Ad showed.');
        },
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          ad.dispose();
          if (_adDismissedCompleter != null &&
              !_adDismissedCompleter!.isCompleted) {
            _adDismissedCompleter!.complete();
          }
          loadInterstitialAd();
        },
        onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
          debugPrint('Interstitial Ad failed to show: $error');
          ad.dispose();
          if (_adDismissedCompleter != null &&
              !_adDismissedCompleter!.isCompleted) {
            _adDismissedCompleter!.complete();
          }
          loadInterstitialAd();
        },
      );

      await ad.show();
      await _adDismissedCompleter!.future;
      return true;
    } catch (e) {
      debugPrint('showInterstitialAd error: $e');
      ad.dispose();
      loadInterstitialAd();
      return false;
    }
  }

  bool get isInterstitialAdReady => _isInterstitialAdReady;

  void disposeInterstitialAd() {
    _interstitialRetryTimer?.cancel();
    _interstitialRetryTimer = null;
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialAdReady = false;
    _isInterstitialAdLoading = false;
    _numInterstitialLoadAttempts = 0;
  }

  // ─── Next Button Interstitial Ad ───────────────────────────────────────────

  Future<void> loadNextButtonInterstitialAd() async {
    if (!_adsEnabled) return;
    if (_isNextButtonInterstitialAdLoading ||
        _nextButtonInterstitialAd != null ||
        (_nextButtonInterstitialRetryTimer?.isActive ?? false)) {
      return;
    }

    if (!_consentCompleted) {
      await requestConsentAndPermissions();
    }
    if (!canRequestAds ||
        _isNextButtonInterstitialAdLoading ||
        _nextButtonInterstitialAd != null) {
      return;
    }

    _isNextButtonInterstitialAdLoading = true;
    InterstitialAd.load(
      adUnitId: nextButtonInterstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          debugPrint('NextButton Interstitial Ad loaded.');
          _isNextButtonInterstitialAdLoading = false;
          _nextButtonInterstitialRetryTimer?.cancel();
          _nextButtonInterstitialRetryTimer = null;
          if (!canRequestAds) {
            ad.dispose();
            return;
          }
          _nextButtonInterstitialAd = ad;
          _isNextButtonInterstitialAdReady = true;
          _numNextButtonInterstitialLoadAttempts = 0;
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('NextButton Interstitial Ad failed: $error');
          _isNextButtonInterstitialAdLoading = false;
          _numNextButtonInterstitialLoadAttempts += 1;
          _nextButtonInterstitialAd = null;
          _isNextButtonInterstitialAdReady = false;

          if (_numNextButtonInterstitialLoadAttempts < maxFailedLoadAttempts) {
            _nextButtonInterstitialRetryTimer = Timer(
              Duration(seconds: _numNextButtonInterstitialLoadAttempts * 3),
              () {
                _nextButtonInterstitialRetryTimer = null;
                loadNextButtonInterstitialAd();
              },
            );
          }
        },
      ),
    );
  }

  Future<bool> showNextButtonInterstitialAd() async {
    if (!_adsEnabled) return false;
    if (!_isNextButtonInterstitialAdReady ||
        _nextButtonInterstitialAd == null) {
      loadNextButtonInterstitialAd();
      return false;
    }

    final ad = _nextButtonInterstitialAd!;
    _nextButtonInterstitialAd = null;
    _isNextButtonInterstitialAdReady = false;

    try {
      _nextButtonAdDismissedCompleter = Completer<void>();

      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (InterstitialAd ad) {
          debugPrint('NextButton Interstitial Ad showed.');
        },
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          ad.dispose();
          if (_nextButtonAdDismissedCompleter != null &&
              !_nextButtonAdDismissedCompleter!.isCompleted) {
            _nextButtonAdDismissedCompleter!.complete();
          }
          loadNextButtonInterstitialAd();
        },
        onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
          debugPrint('NextButton Interstitial Ad failed to show: $error');
          ad.dispose();
          if (_nextButtonAdDismissedCompleter != null &&
              !_nextButtonAdDismissedCompleter!.isCompleted) {
            _nextButtonAdDismissedCompleter!.complete();
          }
          loadNextButtonInterstitialAd();
        },
      );

      await ad.show();
      await _nextButtonAdDismissedCompleter!.future;
      return true;
    } catch (e) {
      debugPrint('showNextButtonInterstitialAd error: $e');
      ad.dispose();
      loadNextButtonInterstitialAd();
      return false;
    }
  }

  bool get isNextButtonInterstitialAdReady => _isNextButtonInterstitialAdReady;

  void disposeNextButtonInterstitialAd() {
    _nextButtonInterstitialRetryTimer?.cancel();
    _nextButtonInterstitialRetryTimer = null;
    _nextButtonInterstitialAd?.dispose();
    _nextButtonInterstitialAd = null;
    _isNextButtonInterstitialAdReady = false;
    _isNextButtonInterstitialAdLoading = false;
    _numNextButtonInterstitialLoadAttempts = 0;
  }

  // ─── Dispose All ───────────────────────────────────────────────────────────

  void dispose() {
    disposeBannerAd();
    disposeBannerAd2();
    disposeInterstitialAd();
    disposeNextButtonInterstitialAd();
  }
}

// ─── AdBannerWidget ──────────────────────────────────────────────────────────

/// Widget wrapper for displaying banner ads.
/// Consent tamamlandıktan sonra otomatik yükler ve başarısız olursa retry yapar.
class AdBannerWidget extends StatefulWidget {
  final bool useSecondAd;

  const AdBannerWidget({super.key, this.useSecondAd = false});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  final AdService _adService = AdService();
  bool _isAdLoaded = false;
  bool _isLoading = false;
  AdSize _adSize = AdSize.banner;

  @override
  void initState() {
    super.initState();
    _initAd();
  }

  Future<void> _initAd() async {
    if (!AdService._adsEnabled) return;
    if (_isLoading) return;
    _isLoading = true;

    // Consent ve ATT izninin tamamlanmasını bekle
    await AdService.requestConsentAndPermissions();

    if (!mounted || !AdService.canRequestAds) {
      _isLoading = false;
      return;
    }

    final availableWidth = MediaQuery.sizeOf(context).width.truncate();
    _adSize =
        await AdSize.getLargeAnchoredAdaptiveBannerAdSize(availableWidth) ??
            AdSize.banner;

    if (!mounted) return;

    // Reklam yükleme isteği — callback ile setState çağrılır
    _loadBanner();
  }

  void _loadBanner() {
    if (!mounted) return;

    if (widget.useSecondAd) {
      _adService.loadBannerAd2(
          size: _adSize,
          onLoaded: () {
            if (mounted) {
              setState(() {
                _isAdLoaded = true;
                _isLoading = false;
              });
            }
          });
      // Zaten hazırsa hemen göster
      if (_adService.isBannerAd2Ready && mounted) {
        setState(() {
          _isAdLoaded = true;
          _isLoading = false;
        });
      }
    } else {
      _adService.loadBannerAd(
          size: _adSize,
          onLoaded: () {
            if (mounted) {
              setState(() {
                _isAdLoaded = true;
                _isLoading = false;
              });
            }
          });
      if (_adService.isBannerAdReady && mounted) {
        setState(() {
          _isAdLoaded = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    if (widget.useSecondAd) {
      _adService.disposeBannerAd2();
    } else {
      _adService.disposeBannerAd();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdService._adsEnabled) return const SizedBox.shrink();

    final BannerAd? ad =
        widget.useSecondAd ? _adService.bannerAd2 : _adService.bannerAd;
    if (AdService.canRequestAds && !_isLoading && ad == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _isAdLoaded = false;
        _initAd();
      });
    }

    if (_isAdLoaded && ad != null) {
      return Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          border: Border.symmetric(
            horizontal: BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        child: SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      );
    }

    // Reklam yüklenene kadar yer tutucu gösterme (boş alan)
    return SizedBox(height: _adSize.height.toDouble() + 16);
  }
}
