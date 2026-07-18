import 'dart:io';
import 'dart:math';

import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/local_widget_ayat.dart';
import 'quran_offline_repository.dart';

/// Yerel ayet mealini ana ekran widget’ına yazar (yalnızca Android).
/// Rastgele ayet; süre dolunca (uygulama açılışı veya sistem widget güncellemesi) yenilenir.
class HomeScreenWidgetService {
  HomeScreenWidgetService._();

  static const String qualifiedAndroidName =
      'com.tahram.gunlukduahadis.DailyContentWidgetProvider';

  static const String _keyListIndex = 'widget_hatim_index';
  static const String _keyExpireAt = 'widget_verse_expire_at';

  /// Kotlin [WidgetHatimStore.ROTATE_MS] ile aynı olmalı.
  static const Duration _verseRotation = Duration(hours: 6);

  static const int _maxTurkishChars = 1100;

  static String _clip(String text, int maxChars) {
    final ch = text.characters;
    if (ch.length <= maxChars) return text;
    return '${ch.take(maxChars)}…';
  }

  static Future<void> _pushRandomAyat(LocalWidgetAyat a, int listIndex) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await HomeWidget.saveWidgetData(_keyListIndex, listIndex);
    await HomeWidget.saveWidgetData(
      _keyExpireAt,
      (now + _verseRotation.inMilliseconds).toString(),
    );
    await HomeWidget.saveWidgetData('ayah_arabic', '');
    await HomeWidget.saveWidgetData(
      'ayah_turkish',
      _clip(a.turkish, _maxTurkishChars),
    );
    await HomeWidget.saveWidgetData('ayah_number', a.ayah.toString());
    await HomeWidget.saveWidgetData('ayah_footer', a.footer);
    await HomeWidget.updateWidget(
      qualifiedAndroidName: qualifiedAndroidName,
    );
  }

  static Future<void> _rollNewRandomVerse() async {
    final repo = QuranOfflineRepository.instance;
    await repo.ensureLoaded();
    final n = repo.totalAyahCount;
    if (n == 0) return;
    final idx = Random().nextInt(n);
    final a = await repo.widgetAyatAtListIndex(idx);
    if (a == null) return;
    await _pushRandomAyat(a, idx);
  }

  /// Uygulama açılışında / widget eklemeden önce: süre dolmuşsa veya metin yoksa rastgele ayet.
  static Future<void> syncRandomVerseForWidget() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await QuranOfflineRepository.instance.ensureLoaded();
      final n = QuranOfflineRepository.instance.totalAyahCount;
      if (n == 0) return;

      final expireRaw =
          await HomeWidget.getWidgetData<String>(_keyExpireAt, defaultValue: '0') ?? '0';
      final expireAt = int.tryParse(expireRaw) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final turkish =
          await HomeWidget.getWidgetData<String>('ayah_turkish', defaultValue: '') ?? '';

      if (now < expireAt && turkish.isNotEmpty) {
        return;
      }

      await _rollNewRandomVerse();
    } catch (_) {}
  }

  static Future<bool> isPinWidgetSupported() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await HomeWidget.isRequestPinWidgetSupported() ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestPinWidgetFromApp() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await syncRandomVerseForWidget();
    try {
      await HomeWidget.requestPinWidget(
        qualifiedAndroidName: qualifiedAndroidName,
      );
    } catch (_) {}
  }
}
