import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class AppReviewGateway {
  Future<bool> isAvailable();
  Future<void> requestReview();
  Future<void> openStoreListing({String? appStoreId});
}

class _NativeAppReviewGateway implements AppReviewGateway {
  final InAppReview _review = InAppReview.instance;

  @override
  Future<bool> isAvailable() => _review.isAvailable();

  @override
  Future<void> requestReview() => _review.requestReview();

  @override
  Future<void> openStoreListing({String? appStoreId}) =>
      _review.openStoreListing(appStoreId: appStoreId);
}

class AppReviewService {
  AppReviewService({AppReviewGateway? gateway})
      : _gateway = gateway ?? _NativeAppReviewGateway();

  static const int minimumLaunchCount = 5;
  static const int minimumMeaningfulActionCount = 3;
  static const Duration minimumUsageAge = Duration(days: 3);
  static const Duration promptCooldown = Duration(days: 180);
  static const String appStoreId = '6792362734';

  static const _firstUseKey = 'app_review_first_use_at';
  static const _launchCountKey = 'app_review_launch_count';
  static const _actionCountKey = 'app_review_meaningful_action_count';
  static const _lastPromptKey = 'app_review_last_prompt_at';

  final AppReviewGateway _gateway;

  Future<void> registerLaunch({DateTime? now}) async {
    final preferences = await SharedPreferences.getInstance();
    final currentTime = now ?? DateTime.now();
    if (!preferences.containsKey(_firstUseKey)) {
      await preferences.setString(_firstUseKey, currentTime.toIso8601String());
    }
    final launches = preferences.getInt(_launchCountKey) ?? 0;
    await preferences.setInt(_launchCountKey, launches + 1);
  }

  Future<bool> registerMeaningfulActionAndMaybeRequest({
    DateTime? now,
  }) async {
    if (kIsWeb) return false;
    final preferences = await SharedPreferences.getInstance();
    final currentTime = now ?? DateTime.now();
    final actions = preferences.getInt(_actionCountKey) ?? 0;
    await preferences.setInt(
      _actionCountKey,
      (actions + 1).clamp(0, minimumMeaningfulActionCount),
    );

    if (!_isEligible(preferences, currentTime)) return false;

    try {
      if (!await _gateway.isAvailable()) return false;
      // Tarihi API çağrısından önce yazarak hızlı çift dokunmalarda
      // aynı anda iki değerlendirme isteği açılmasını engelleriz.
      await preferences.setString(
        _lastPromptKey,
        currentTime.toIso8601String(),
      );
      await _gateway.requestReview();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> openStoreListing() async {
    if (kIsWeb) return;
    await _gateway.openStoreListing(appStoreId: appStoreId);
  }

  bool _isEligible(SharedPreferences preferences, DateTime now) {
    final launches = preferences.getInt(_launchCountKey) ?? 0;
    final actions = preferences.getInt(_actionCountKey) ?? 0;
    if (launches < minimumLaunchCount ||
        actions < minimumMeaningfulActionCount) {
      return false;
    }

    final firstUse = DateTime.tryParse(
      preferences.getString(_firstUseKey) ?? '',
    );
    if (firstUse == null || now.difference(firstUse) < minimumUsageAge) {
      return false;
    }

    final lastPrompt = DateTime.tryParse(
      preferences.getString(_lastPromptKey) ?? '',
    );
    return lastPrompt == null || now.difference(lastPrompt) >= promptCooldown;
  }
}
