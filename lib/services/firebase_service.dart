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
      debugPrint('🔥 ==========================================');
      debugPrint('🔥 Starting Firebase initialization...');
      
      // Initialize Firebase
      debugPrint('🔥 Step 1: Calling Firebase.initializeApp()...');
      await Firebase.initializeApp();
      debugPrint('🔥 Step 1: ✅ Firebase.initializeApp() completed');
      
      // Get instances
      debugPrint('🔥 Step 2: Getting Firebase Analytics instance...');
      _analytics = FirebaseAnalytics.instance;
      debugPrint('🔥 Step 2: ✅ Firebase Analytics instance obtained');
      
      debugPrint('🔥 Step 3: Getting Firebase Crashlytics instance...');
      _crashlytics = FirebaseCrashlytics.instance;
      debugPrint('🔥 Step 3: ✅ Firebase Crashlytics instance obtained');
      
      // Enable Crashlytics collection in debug mode (optional)
      if (kDebugMode) {
        debugPrint('🔥 Step 4: Debug mode detected - Disabling Crashlytics collection');
        // Set to true to enable crash reporting in debug mode
        await _crashlytics?.setCrashlyticsCollectionEnabled(false);
      } else {
        debugPrint('🔥 Step 4: Release mode detected - Enabling Crashlytics collection');
        // Always enabled in release mode
        await _crashlytics?.setCrashlyticsCollectionEnabled(true);
      }
      
      // Pass all uncaught errors to Crashlytics
      FlutterError.onError = (errorDetails) {
        debugPrint('🔥 Flutter error caught, sending to Crashlytics');
        _crashlytics?.recordFlutterFatalError(errorDetails);
      };
      
      // Pass all uncaught asynchronous errors to Crashlytics
      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('🔥 Platform error caught, sending to Crashlytics');
        _crashlytics?.recordError(error, stack, fatal: true);
        return true;
      };
      
      debugPrint('✅ ==========================================');
      debugPrint('✅ Firebase initialized successfully!');
      debugPrint('✅ Analytics ready: ${_analytics != null}');
      debugPrint('✅ Crashlytics ready: ${_crashlytics != null}');
      debugPrint('✅ ==========================================');
    } catch (e, stackTrace) {
      debugPrint('❌ ==========================================');
      debugPrint('❌ ERROR: Firebase initialization failed!');
      debugPrint('❌ Error: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      debugPrint('❌ ==========================================');
      // Don't throw error - app should work without Firebase
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
    } catch (e) {
      print('❌ Error logging event: $e');
    }
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
    } catch (e) {
      print('❌ Error logging screen view: $e');
    }
  }

  /// Set user property
  static Future<void> setUserProperty({
    required String name,
    String? value,
  }) async {
    try {
      await _analytics?.setUserProperty(name: name, value: value);
    } catch (e) {
      print('❌ Error setting user property: $e');
    }
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
    } catch (e) {
      print('❌ Error logging to Crashlytics: $e');
    }
  }

  /// Log message to Crashlytics
  static Future<void> logMessage(String message) async {
    try {
      await _crashlytics?.log(message);
    } catch (e) {
      print('❌ Error logging message: $e');
    }
  }

  /// Set user identifier for Crashlytics
  static Future<void> setUserId(String userId) async {
    try {
      await _crashlytics?.setUserIdentifier(userId);
    } catch (e) {
      print('❌ Error setting user ID: $e');
    }
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
  
  // User actions
  static const String dailyItemViewed = 'daily_item_viewed';
  static const String dailyItemRead = 'daily_item_read';
  static const String dailyItemShared = 'daily_item_shared';
  static const String randomItemViewed = 'random_item_viewed';
  static const String reminderEnabled = 'reminder_enabled';
  static const String reminderDisabled = 'reminder_disabled';
  static const String reminderShown = 'reminder_shown';
  
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
}

