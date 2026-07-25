import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
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

  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;
  int _bannerFailedAttempts = 0;

  BannerAd? _bannerAd2;
  bool _isBannerAd2Ready = false;
  int _banner2FailedAttempts = 0;

  /// Banner reklam basarisiz oldugunda kullanilan artan bekleme suresi.
  /// AdMob, ard arda hizli tekrar denemeleri "invalid traffic" olarak
  /// isaretleyip reklam birimini daha da az doldurabilir; bu yuzden
  /// sabit 3sn yerine ustel geri cekilme (exponential backoff) kullaniyoruz.
  static Duration _bannerRetryDelay(int attempt) {
    final seconds = 5 * (1 << attempt.clamp(0, 5)); // 5, 10, 20, 40, 80, 160...
    return Duration(seconds: seconds.clamp(5, 120));
  }

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;
  int _numInterstitialLoadAttempts = 0;
  static const int maxFailedLoadAttempts = 3;
  Completer<void>? _adDismissedCompleter;

  InterstitialAd? _nextButtonInterstitialAd;
  bool _isNextButtonInterstitialAdReady = false;
  int _numNextButtonInterstitialLoadAttempts = 0;
  Completer<void>? _nextButtonAdDismissedCompleter;

  // Consent durumu
  static bool _consentChecked = false;
  static bool _consentCompleted = false;
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

    // Maksimum 5 saniye bekle
    await Future.any([
      completer.future,
      Future.delayed(const Duration(seconds: 5)),
    ]);
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
    // Maksimum 10 saniye bekle
    await Future.any([
      completer.future,
      Future.delayed(const Duration(seconds: 10)),
    ]);
  }

  /// Initialize AdMob
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  /// Banner Ad Unit ID - Ana Sayfa Alt Banner
  String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-9132542494292379/9084351705';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-9132542494292379/8967728449';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  /// Interstitial Ad Unit ID - Paylaşım Öncesi
  String get interstitialAdUnitId {
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
  void loadBannerAd({VoidCallback? onLoaded}) {
    if (!_adsEnabled) return;
    if (_bannerAd != null) {
      // Zaten yüklü ya da yükleniyor
      if (_isBannerAdReady) onLoaded?.call();
      return;
    }

    _bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
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
          // Ustel geri cekilme ile tekrar dene (invalid traffic riskini onlemek icin)
          final delay = _bannerRetryDelay(_bannerFailedAttempts);
          _bannerFailedAttempts++;
          Future.delayed(delay, () {
            loadBannerAd(onLoaded: onLoaded);
          });
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
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerAdReady = false;
  }

  // ─── Banner Ad 2 ───────────────────────────────────────────────────────────

  /// Load second banner ad — consent tamamlandıktan sonra çağrılmalı
  void loadBannerAd2({VoidCallback? onLoaded}) {
    if (!_adsEnabled) return;
    if (_bannerAd2 != null) {
      if (_isBannerAd2Ready) onLoaded?.call();
      return;
    }

    _bannerAd2 = BannerAd(
      adUnitId: bannerAd2UnitId,
      size: AdSize.banner,
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
          // Ustel geri cekilme ile tekrar dene (invalid traffic riskini onlemek icin)
          final delay = _bannerRetryDelay(_banner2FailedAttempts);
          _banner2FailedAttempts++;
          Future.delayed(delay, () {
            loadBannerAd2(onLoaded: onLoaded);
          });
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
    _bannerAd2?.dispose();
    _bannerAd2 = null;
    _isBannerAd2Ready = false;
  }

  // ─── Interstitial Ad (Paylaşım) ────────────────────────────────────────────

  Future<void> loadInterstitialAd() async {
    if (!_adsEnabled) return;

    // Consent tamamlanmamışsa bekle
    if (!_consentCompleted) {
      await requestConsentAndPermissions();
    }

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          debugPrint('Interstitial Ad loaded.');
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          _numInterstitialLoadAttempts = 0;
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('Interstitial Ad failed to load: $error');
          _numInterstitialLoadAttempts += 1;
          _interstitialAd = null;
          _isInterstitialAdReady = false;

          if (_numInterstitialLoadAttempts < maxFailedLoadAttempts) {
            Future.delayed(
              Duration(seconds: _numInterstitialLoadAttempts * 3),
              loadInterstitialAd,
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

    try {
      _adDismissedCompleter = Completer<void>();

      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (InterstitialAd ad) {
          debugPrint('Interstitial Ad showed.');
        },
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          ad.dispose();
          _interstitialAd = null;
          _isInterstitialAdReady = false;
          if (_adDismissedCompleter != null &&
              !_adDismissedCompleter!.isCompleted) {
            _adDismissedCompleter!.complete();
          }
          loadInterstitialAd();
        },
        onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
          debugPrint('Interstitial Ad failed to show: $error');
          ad.dispose();
          _interstitialAd = null;
          _isInterstitialAdReady = false;
          if (_adDismissedCompleter != null &&
              !_adDismissedCompleter!.isCompleted) {
            _adDismissedCompleter!.complete();
          }
          loadInterstitialAd();
        },
      );

      await _interstitialAd!.show();
      await _adDismissedCompleter!.future;
      return true;
    } catch (e) {
      debugPrint('showInterstitialAd error: $e');
      return false;
    }
  }

  bool get isInterstitialAdReady => _isInterstitialAdReady;

  void disposeInterstitialAd() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialAdReady = false;
  }

  // ─── Next Button Interstitial Ad ───────────────────────────────────────────

  Future<void> loadNextButtonInterstitialAd() async {
    if (!_adsEnabled) return;

    if (!_consentCompleted) {
      await requestConsentAndPermissions();
    }

    InterstitialAd.load(
      adUnitId: nextButtonInterstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          debugPrint('NextButton Interstitial Ad loaded.');
          _nextButtonInterstitialAd = ad;
          _isNextButtonInterstitialAdReady = true;
          _numNextButtonInterstitialLoadAttempts = 0;
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('NextButton Interstitial Ad failed: $error');
          _numNextButtonInterstitialLoadAttempts += 1;
          _nextButtonInterstitialAd = null;
          _isNextButtonInterstitialAdReady = false;

          if (_numNextButtonInterstitialLoadAttempts < maxFailedLoadAttempts) {
            Future.delayed(
              Duration(seconds: _numNextButtonInterstitialLoadAttempts * 3),
              loadNextButtonInterstitialAd,
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

    try {
      _nextButtonAdDismissedCompleter = Completer<void>();

      _nextButtonInterstitialAd!.fullScreenContentCallback =
          FullScreenContentCallback(
        onAdShowedFullScreenContent: (InterstitialAd ad) {
          debugPrint('NextButton Interstitial Ad showed.');
        },
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          ad.dispose();
          _nextButtonInterstitialAd = null;
          _isNextButtonInterstitialAdReady = false;
          if (_nextButtonAdDismissedCompleter != null &&
              !_nextButtonAdDismissedCompleter!.isCompleted) {
            _nextButtonAdDismissedCompleter!.complete();
          }
          loadNextButtonInterstitialAd();
        },
        onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
          debugPrint('NextButton Interstitial Ad failed to show: $error');
          ad.dispose();
          _nextButtonInterstitialAd = null;
          _isNextButtonInterstitialAdReady = false;
          if (_nextButtonAdDismissedCompleter != null &&
              !_nextButtonAdDismissedCompleter!.isCompleted) {
            _nextButtonAdDismissedCompleter!.complete();
          }
          loadNextButtonInterstitialAd();
        },
      );

      await _nextButtonInterstitialAd!.show();
      await _nextButtonAdDismissedCompleter!.future;
      return true;
    } catch (e) {
      debugPrint('showNextButtonInterstitialAd error: $e');
      return false;
    }
  }

  bool get isNextButtonInterstitialAdReady => _isNextButtonInterstitialAdReady;

  void disposeNextButtonInterstitialAd() {
    _nextButtonInterstitialAd?.dispose();
    _nextButtonInterstitialAd = null;
    _isNextButtonInterstitialAdReady = false;
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

    if (!mounted) return;

    // Reklam yükleme isteği — callback ile setState çağrılır
    _loadBanner();
  }

  void _loadBanner() {
    if (!mounted) return;

    if (widget.useSecondAd) {
      _adService.loadBannerAd2(onLoaded: () {
        if (mounted) {
          setState(() => _isAdLoaded = true);
        }
      });
      // Zaten hazırsa hemen göster
      if (_adService.isBannerAd2Ready && mounted) {
        setState(() => _isAdLoaded = true);
      }
    } else {
      _adService.loadBannerAd(onLoaded: () {
        if (mounted) {
          setState(() => _isAdLoaded = true);
        }
      });
      if (_adService.isBannerAdReady && mounted) {
        setState(() => _isAdLoaded = true);
      }
    }
  }

  @override
  void dispose() {
    // Singleton olduğu için dispose etmiyoruz — uygulama genelinde paylaşılıyor
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdService._adsEnabled) return const SizedBox.shrink();

    final BannerAd? ad =
        widget.useSecondAd ? _adService.bannerAd2 : _adService.bannerAd;

    if (_isAdLoaded && ad != null) {
      return Container(
        alignment: Alignment.center,
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: AdWidget(ad: ad),
      );
    }

    // Reklam yüklenene kadar yer tutucu gösterme (boş alan)
    return const SizedBox(height: 50);
  }
}
