import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/app_update_policy.dart';

class AppUpdateService {
  static const androidKey = 'app_update_android';
  static const iosKey = 'app_update_ios';
  static const maximumPolicyAge = Duration(hours: 24);

  Future<AppUpdateDecision?> check() async {
    if (kIsWeb ||
        !(Platform.isAndroid || Platform.isIOS) ||
        Firebase.apps.isEmpty) {
      return null;
    }
    try {
      final config = FirebaseRemoteConfig.instance;
      await config.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 8),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await config.setDefaults(
          {androidKey: '{"enabled":false}', iosKey: '{"enabled":false}'});
      await config.ensureInitialized();
      try {
        await config.fetchAndActivate();
      } catch (error) {
        debugPrint('Update policy refresh failed: $error');
      }
      // Expire cached enforcement so an unavailable backend cannot lock an
      // offline installation indefinitely. A fresh valid policy is required.
      final age = DateTime.now().difference(config.lastFetchTime);
      if (age.isNegative || age > maximumPolicyAge) return null;
      final info = await PackageInfo.fromPlatform();
      return evaluateAppUpdate(
          config.getString(Platform.isIOS ? iosKey : androidKey), info.version);
    } catch (error) {
      debugPrint('Update check failed: $error');
      return null;
    }
  }
}
