import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Service to handle Firebase Analytics and Crashlytics
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  static FirebaseAnalytics? _analytics;
  static FirebaseCrashlytics? _crashlytics;

  /// Initialize Firebase
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      _analytics = FirebaseAnalytics.instance;
      _crashlytics = FirebaseCrashlytics.instance;
      
      if (kDebugMode) {
        await _crashlytics?.setCrashlyticsCollectionEnabled(false);
      } else {
        await _crashlytics?.setCrashlyticsCollectionEnabled(true);
      }
      
      FlutterError.onError = (errorDetails) {
        _crashlytics?.recordFlutterFatalError(errorDetails);
      };
      
      PlatformDispatcher.instance.onError = (error, stack) {
        _crashlytics?.recordError(error, stack, fatal: true);
        return true;
      };
    } catch (e, stackTrace) {
      // App continues without Firebase
    }
  }

  /// Log an event to Analytics
  static Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics?.logEvent(
        name: name,
        parameters: parameters,
      );
    } catch (e) {}
  }

  /// Log screen view
  static Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      await _analytics?.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
    } catch (e) {}
  }

  /// Set user property
  static Future<void> setUserProperty({
    required String name,
    String? value,
  }) async {
    try {
      await _analytics?.setUserProperty(name: name, value: value);
    } catch (e) {}
  }

  /// Log custom error to Crashlytics
  static Future<void> logError({
    required dynamic exception,
    StackTrace? stackTrace,
    String? reason,
    bool fatal = false,
  }) async {
    try {
      await _crashlytics?.recordError(
        exception,
        stackTrace,
        reason: reason,
        fatal: fatal,
      );
    } catch (e) {}
  }

  /// Log message to Crashlytics
  static Future<void> logMessage(String message) async {
    try {
      await _crashlytics?.log(message);
    } catch (e) {}
  }

  /// Set user identifier for Crashlytics
  static Future<void> setUserId(String userId) async {
    try {
      await _crashlytics?.setUserIdentifier(userId);
    } catch (e) {}
  }

  /// Get Analytics instance
  static FirebaseAnalytics? get analytics => _analytics;

  /// Get Crashlytics instance
  static FirebaseCrashlytics? get crashlytics => _crashlytics;
}

/// Pre-defined Analytics Events
class AnalyticsEvents {
  // Screen views
  static const String screenHome = 'screen_home';
  static const String screenSettings = 'screen_settings';
  static const String screenRamadan = 'screen_ramadan';
  static const String screenQuran = 'screen_quran';

  // User actions
  static const String dailyItemViewed = 'daily_item_viewed';
  static const String dailyItemRead = 'daily_item_read';
  static const String dailyItemShared = 'daily_item_shared';
  static const String randomItemViewed = 'random_item_viewed';
  static const String reminderEnabled = 'reminder_enabled';
  static const String reminderDisabled = 'reminder_disabled';
  static const String reminderShown = 'reminder_shown';
  
  // Ramadan feature events
  static const String ramadanScreenViewed = 'ramadan_screen_viewed';
  static const String ramadanCitySelected = 'ramadan_city_selected';
  static const String ramadanTimesLoaded = 'ramadan_times_loaded';
  static const String ramadanTimesRefreshed = 'ramadan_times_refreshed';
  static const String greetingShared = 'greeting_shared';

  // Quran feature events
  static const String quranScreenViewed = 'quran_screen_viewed';
  static const String quranSurahPlayed = 'quran_surah_played';

  // Content types
  static const String itemTypeDua = 'dua';
  static const String itemTypeHadith = 'hadith';
  static const String itemTypeAyah = 'ayah';
}

/// Analytics Event Parameters
class AnalyticsParams {
  static const String itemType = 'item_type';
  static const String itemSource = 'item_source';
  static const String readingStreak = 'reading_streak';
  static const String reminderTime = 'reminder_time';
  static const String cityName = 'city_name';
  static const String year = 'year';
  static const String category = 'category';
  static const String messageType = 'message_type';
  static const String surahNumber = 'surah_number';
  static const String reciterId = 'reciter_id';
}

