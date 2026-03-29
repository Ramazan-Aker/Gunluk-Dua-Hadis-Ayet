import 'dart:io';

import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/local_widget_ayat.dart';
import 'quran_offline_repository.dart';

/// Yerel ayet + meal verisini ana ekran widget’ına yazar (yalnızca Android).
/// Hatim modu: Fâtiha 1’den başlar; yalnızca önceki/sonraki ile geçiş (otomatik süre yok).
class HomeScreenWidgetService {
  HomeScreenWidgetService._();

  static const String qualifiedAndroidName =
      'com.tahram.gunlukduahadis.DailyContentWidgetProvider';

  static const String _keyHatimIndex = 'widget_hatim_index';
  static const String _keyExpireAt = 'widget_verse_expire_at';
  static const String _keyAdvanceMs = 'widget_auto_advance_ms';

  /// Uzun ayet/meal için üst sınır (grafem); çok uzun surelerde widget’ı dikey büyütün.
  static const int _maxArabicChars = 600;
  static const int _maxTurkishChars = 1100;

  static String _clip(String text, int maxChars) {
    final ch = text.characters;
    if (ch.length <= maxChars) return text;
    return '${ch.take(maxChars)}…';
  }

  static Future<void> _clearAutoAdvanceKeys() async {
    await HomeWidget.saveWidgetData(_keyAdvanceMs, 0);
    await HomeWidget.saveWidgetData(_keyExpireAt, '0');
  }

  static Future<void> _pushAyat(LocalWidgetAyat a) async {
    await HomeWidget.saveWidgetData('ayah_arabic', _clip(a.arabic, _maxArabicChars));
    await HomeWidget.saveWidgetData(
      'ayah_turkish',
      _clip(a.turkish, _maxTurkishChars),
    );
    await HomeWidget.saveWidgetData('ayah_number', a.ayah.toString());
    await HomeWidget.saveWidgetData('ayah_footer', a.footer);
    await _clearAutoAdvanceKeys();
    await HomeWidget.updateWidget(
      qualifiedAndroidName: qualifiedAndroidName,
    );
  }

  static Future<void> _showVerseAtListIndex(int index) async {
    final repo = QuranOfflineRepository.instance;
    await repo.ensureLoaded();
    final n = repo.totalAyahCount;
    if (n == 0) return;
    var i = index;
    if (i < 0) i = 0;
    if (i >= n) i = n - 1;
    final a = await repo.widgetAyatAtListIndex(i);
    if (a == null) return;
    await HomeWidget.saveWidgetData(_keyHatimIndex, i);
    await _pushAyat(a);
  }

  /// Uygulama açılışında veya widget eklemeden önce: mevcut indeksteki ayeti yazar; otomatik süre kapatılır.
  static Future<void> syncHatimVerseForWidget() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _clearAutoAdvanceKeys();
      await QuranOfflineRepository.instance.ensureLoaded();
      final n = QuranOfflineRepository.instance.totalAyahCount;
      if (n == 0) return;
      final raw = await HomeWidget.getWidgetData<int>(_keyHatimIndex, defaultValue: 0) ?? 0;
      var i = raw;
      if (i < 0) i = 0;
      if (i >= n) i = n - 1;
      await _showVerseAtListIndex(i);
    } catch (_) {}
  }

  /// Widget üzerindeki önceki / sonraki düğmeleri.
  static Future<void> widgetNavigateRelative(int delta) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await QuranOfflineRepository.instance.ensureLoaded();
      final n = QuranOfflineRepository.instance.totalAyahCount;
      if (n == 0) return;

      final raw = await HomeWidget.getWidgetData<int>(_keyHatimIndex, defaultValue: 0) ?? 0;
      var i = raw + delta;
      if (i < 0) i = 0;
      if (i >= n) i = n - 1;
      await _showVerseAtListIndex(i);
    } catch (_) {}
  }

  /// Bazı launcher’larda “Widget’ı sabitle” sistem diyaloğu (API 26+).
  static Future<bool> isPinWidgetSupported() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await HomeWidget.isRequestPinWidgetSupported() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Önce veriyi yazar, sonra pin isteği gönderir.
  static Future<void> requestPinWidgetFromApp() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await syncHatimVerseForWidget();
    try {
      await HomeWidget.requestPinWidget(
        qualifiedAndroidName: qualifiedAndroidName,
      );
    } catch (_) {}
  }
}
