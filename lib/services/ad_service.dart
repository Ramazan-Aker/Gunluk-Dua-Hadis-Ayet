import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';

/// Service class to handle Google AdMob banner ads
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  /// Ekran görüntüsü için geçici olarak false - sonra true yapın
  static const bool _adsEnabled = true;

  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;
  
  BannerAd? _bannerAd2;
  bool _isBannerAd2Ready = false;
  
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;
  int _numInterstitialLoadAttempts = 0;
  static const int maxFailedLoadAttempts = 3;
  Completer<void>? _adDismissedCompleter;
  
  InterstitialAd? _nextButtonInterstitialAd;
  bool _isNextButtonInterstitialAdReady = false;
  int _numNextButtonInterstitialLoadAttempts = 0;
  Completer<void>? _nextButtonAdDismissedCompleter;

  /// Initialize AdMob
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  /// Get Ad Unit IDs based on platform
  /// 
  /// Banner Ad Unit ID - Ana Sayfa Alt Banner
  String get bannerAdUnitId {
    if (Platform.isAndroid) {
      // Banner Ad Unit ID for Android
      return 'ca-app-pub-9132542494292379/9084351705';
    } else if (Platform.isIOS) {
      // iOS Ad Unit ID
      return 'ca-app-pub-9132542494292379/9084351705';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }
  
  /// Get Interstitial Ad Unit ID - Paylaşım Öncesi
  String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      // Interstitial Ad Unit ID for Android
      return 'ca-app-pub-9132542494292379/8757048647';
    } else if (Platform.isIOS) {
      // iOS Ad Unit ID
      return 'ca-app-pub-9132542494292379/8757048647';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }
  
  /// Get Next Button Interstitial Ad Unit ID - Sonraki Butonu (4 tıklama sonrası)
  String get nextButtonInterstitialAdUnitId {
    if (Platform.isAndroid) {
      // Next Button Interstitial Ad Unit ID for Android
      return 'ca-app-pub-9132542494292379/7443966973';
    } else if (Platform.isIOS) {
      // iOS Ad Unit ID
      return 'ca-app-pub-9132542494292379/7443966973';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }
  
  /// Get Second Banner Ad Unit ID - Üst Banner
  String get bannerAd2UnitId {
    if (Platform.isAndroid) {
      // Second Banner Ad Unit ID for Android
      return 'ca-app-pub-9132542494292379/5145106696';
    } else if (Platform.isIOS) {
      // iOS Ad Unit ID
      return 'ca-app-pub-9132542494292379/5145106696';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  /// Load banner ad
  void loadBannerAd() {
    if (!_adsEnabled) return;
    // Don't reload if already loading or loaded
    if (_bannerAd != null) return;
    
    _bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _isBannerAdReady = true;
        },
        onAdFailedToLoad: (ad, error) {
          _isBannerAdReady = false;
          ad.dispose();
          _bannerAd = null;
        },
        onAdOpened: (ad) {},
        onAdClosed: (ad) {},
      ),
    );

    _bannerAd?.load();
  }

  /// Get banner ad
  BannerAd? get bannerAd => _bannerAd;

  /// Check if banner ad is ready
  bool get isBannerAdReady => _adsEnabled && _isBannerAdReady;

  /// Dispose banner ad
  void disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerAdReady = false;
  }
  
  /// Load second banner ad (for use in item card area)
  void loadBannerAd2() {
    if (!_adsEnabled) return;
    // Don't reload if already loading or loaded
    if (_bannerAd2 != null) return;
    
    _bannerAd2 = BannerAd(
      adUnitId: bannerAd2UnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _isBannerAd2Ready = true;
        },
        onAdFailedToLoad: (ad, error) {
          _isBannerAd2Ready = false;
          ad.dispose();
          _bannerAd2 = null;
        },
        onAdOpened: (ad) {},
        onAdClosed: (ad) {},
      ),
    );

    _bannerAd2?.load();
  }

  /// Get second banner ad
  BannerAd? get bannerAd2 => _bannerAd2;

  /// Check if second banner ad is ready
  bool get isBannerAd2Ready => _adsEnabled && _isBannerAd2Ready;

  /// Dispose second banner ad
  void disposeBannerAd2() {
    _bannerAd2?.dispose();
    _bannerAd2 = null;
    _isBannerAd2Ready = false;
  }

  /// Load interstitial ad
  Future<void> loadInterstitialAd() async {
    if (!_adsEnabled) return;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          _numInterstitialLoadAttempts = 0;
          
          // Set up full screen content callback - will be reset when showing
          // (keeping this for initial setup, but will be overridden in show method)
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (InterstitialAd ad) {},
            onAdDismissedFullScreenContent: (InterstitialAd ad) {
              ad.dispose();
              _interstitialAd = null;
              _isInterstitialAdReady = false;
              loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
              ad.dispose();
              _interstitialAd = null;
              _isInterstitialAdReady = false;
              loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          _numInterstitialLoadAttempts += 1;
          _interstitialAd = null;
          _isInterstitialAdReady = false;
          
          // Retry loading with exponential backoff
          if (_numInterstitialLoadAttempts < maxFailedLoadAttempts) {
            Future.delayed(
              Duration(seconds: _numInterstitialLoadAttempts * 2),
              loadInterstitialAd,
            );
          }
        },
      ),
    );
  }

  /// Show interstitial ad and wait for it to be dismissed
  /// Returns true if ad was shown, false otherwise
  Future<bool> showInterstitialAd() async {
    if (!_adsEnabled) return false;
    if (_isInterstitialAdReady && _interstitialAd != null) {
      try {
        // Create a completer to wait for ad dismissal
        _adDismissedCompleter = Completer<void>();
        
        // Set up callback that completes when ad is dismissed
        _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
          onAdShowedFullScreenContent: (InterstitialAd ad) {},
          onAdDismissedFullScreenContent: (InterstitialAd ad) {
            ad.dispose();
            _interstitialAd = null;
            _isInterstitialAdReady = false;
            
            // Complete the completer so code can continue
            if (_adDismissedCompleter != null && !_adDismissedCompleter!.isCompleted) {
              _adDismissedCompleter!.complete();
            }
            
            // Load next ad
            loadInterstitialAd();
          },
          onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
            ad.dispose();
            _interstitialAd = null;
            _isInterstitialAdReady = false;
            
            // Complete the completer even on error
            if (_adDismissedCompleter != null && !_adDismissedCompleter!.isCompleted) {
              _adDismissedCompleter!.complete();
            }
            
            // Load next ad
            loadInterstitialAd();
          },
        );
        
        // Show the ad
        await _interstitialAd!.show();
        
        // Wait for ad to be dismissed
        await _adDismissedCompleter!.future;
        return true;
      } catch (e) {
        return false;
      }
    } else {
      // Try to load for next time
      loadInterstitialAd();
      return false;
    }
  }

  /// Check if interstitial ad is ready
  bool get isInterstitialAdReady => _isInterstitialAdReady;

  /// Dispose interstitial ad
  void disposeInterstitialAd() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialAdReady = false;
  }

  /// Load next button interstitial ad
  Future<void> loadNextButtonInterstitialAd() async {
    if (!_adsEnabled) return;
    InterstitialAd.load(
      adUnitId: nextButtonInterstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _nextButtonInterstitialAd = ad;
          _isNextButtonInterstitialAdReady = true;
          _numNextButtonInterstitialLoadAttempts = 0;
          
          // Set up full screen content callback
          _nextButtonInterstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (InterstitialAd ad) {},
            onAdDismissedFullScreenContent: (InterstitialAd ad) {
              ad.dispose();
              _nextButtonInterstitialAd = null;
              _isNextButtonInterstitialAdReady = false;
              loadNextButtonInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
              ad.dispose();
              _nextButtonInterstitialAd = null;
              _isNextButtonInterstitialAdReady = false;
              loadNextButtonInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          _numNextButtonInterstitialLoadAttempts += 1;
          _nextButtonInterstitialAd = null;
          _isNextButtonInterstitialAdReady = false;
          
          // Retry loading with exponential backoff
          if (_numNextButtonInterstitialLoadAttempts < maxFailedLoadAttempts) {
            Future.delayed(
              Duration(seconds: _numNextButtonInterstitialLoadAttempts * 2),
              loadNextButtonInterstitialAd,
            );
          }
        },
      ),
    );
  }

  /// Show next button interstitial ad and wait for it to be dismissed
  /// Returns true if ad was shown, false otherwise
  Future<bool> showNextButtonInterstitialAd() async {
    if (!_adsEnabled) return false;
    if (_isNextButtonInterstitialAdReady && _nextButtonInterstitialAd != null) {
      try {
        // Create a completer to wait for ad dismissal
        _nextButtonAdDismissedCompleter = Completer<void>();
        
        // Set up callback that completes when ad is dismissed
        _nextButtonInterstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
          onAdShowedFullScreenContent: (InterstitialAd ad) {},
          onAdDismissedFullScreenContent: (InterstitialAd ad) {
            ad.dispose();
            _nextButtonInterstitialAd = null;
            _isNextButtonInterstitialAdReady = false;
            
            // Complete the completer so code can continue
            if (_nextButtonAdDismissedCompleter != null && !_nextButtonAdDismissedCompleter!.isCompleted) {
              _nextButtonAdDismissedCompleter!.complete();
            }
            
            // Load next ad
            loadNextButtonInterstitialAd();
          },
          onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
            ad.dispose();
            _nextButtonInterstitialAd = null;
            _isNextButtonInterstitialAdReady = false;
            
            // Complete the completer even on error
            if (_nextButtonAdDismissedCompleter != null && !_nextButtonAdDismissedCompleter!.isCompleted) {
              _nextButtonAdDismissedCompleter!.complete();
            }
            
            // Load next ad
            loadNextButtonInterstitialAd();
          },
        );
        
        // Show the ad
        await _nextButtonInterstitialAd!.show();
        
        // Wait for ad to be dismissed
        await _nextButtonAdDismissedCompleter!.future;
        return true;
      } catch (e) {
        return false;
      }
    } else {
      // Try to load for next time
      loadNextButtonInterstitialAd();
      return false;
    }
  }

  /// Check if next button interstitial ad is ready
  bool get isNextButtonInterstitialAdReady => _isNextButtonInterstitialAdReady;

  /// Dispose next button interstitial ad
  void disposeNextButtonInterstitialAd() {
    _nextButtonInterstitialAd?.dispose();
    _nextButtonInterstitialAd = null;
    _isNextButtonInterstitialAdReady = false;
  }

  /// Dispose all ads
  void dispose() {
    disposeBannerAd();
    disposeBannerAd2();
    disposeInterstitialAd();
    disposeNextButtonInterstitialAd();
  }
}

/// Widget wrapper for displaying banner ads
/// Usage: AdBannerWidget()
class AdBannerWidget extends StatefulWidget {
  final bool useSecondAd;
  
  const AdBannerWidget({super.key, this.useSecondAd = false});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  final AdService _adService = AdService();
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    if (!AdService._adsEnabled) return;
    // Load appropriate banner ad
    if (widget.useSecondAd) {
      _adService.loadBannerAd2();
    } else {
      _adService.loadBannerAd();
    }
    
    // Check every 500ms if ad is loaded (up to 10 seconds)
    int attempts = 0;
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      attempts++;
      final bool isReady = widget.useSecondAd 
          ? _adService.isBannerAd2Ready 
          : _adService.isBannerAdReady;
          
      if (isReady) {
        if (mounted) {
          setState(() {
            _isAdLoaded = true;
          });
        }
        timer.cancel();
      } else if (attempts > 20) {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    // Don't dispose banner ad here since it's singleton
    // It will be reused across the app
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdService._adsEnabled) return const SizedBox.shrink();
    final BannerAd? ad = widget.useSecondAd ? _adService.bannerAd2 : _adService.bannerAd;
    
    if (_isAdLoaded && ad != null) {
      return Container(
        alignment: Alignment.center,
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: AdWidget(ad: ad),
      );
    } else {
      // Placeholder while ad is loading
      return Container(
        height: 50,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: const Center(
          child: Text(
            'Reklam yükleniyor...',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
      );
    }
  }
}
