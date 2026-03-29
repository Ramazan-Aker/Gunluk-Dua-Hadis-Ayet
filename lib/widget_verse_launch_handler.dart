import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

import 'widget_verse_pending.dart';

/// Widget’tan `hergunislam://widgetVerse?i=N` ile Kur’an sekmesinde ilgili sure/ayet ekranına gider.
class WidgetVerseLaunchHandler {
  WidgetVerseLaunchHandler._();

  static const String _host = 'widgetVerse';
  static const String _param = 'i';
  static const String _hatimKey = 'widget_hatim_index';

  static bool _isWidgetVerseUri(Uri uri) =>
      uri.scheme == 'hergunislam' && uri.host == _host;

  /// Eklenti bazen boş [Uri] döndürür (data yok); o zaman son hatim indeksinden URI üret.
  /// [uri] null ise (normal ikonla açılış) dokunulmaz.
  static Future<Uri?> _ensureWidgetVerseUri(Uri? uri) async {
    if (uri == null) return null;
    if (_isWidgetVerseUri(uri)) return uri;
    if (kIsWeb || !Platform.isAndroid) return uri;

    final emptyPluginUri = uri.scheme.isEmpty && uri.host.isEmpty;
    if (emptyPluginUri) {
      final idx = await HomeWidget.getWidgetData<int>(_hatimKey, defaultValue: 0) ?? 0;
      return Uri.parse('hergunislam://widgetVerse?i=$idx');
    }
    return uri;
  }

  static void handleUri(Uri? uri) {
    if (uri == null) return;
    if (!_isWidgetVerseUri(uri)) return;
    final raw = uri.queryParameters[_param] ?? uri.queryParameters['listIndex'];
    final idx = int.tryParse(raw ?? '');
    if (idx == null || idx < 0) return;

    pendingWidgetVerseListIndex.value = null;
    pendingWidgetVerseListIndex.value = idx;
  }

  static Future<void> handleInitialLaunch() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final raw = await HomeWidget.initiallyLaunchedFromHomeWidget();
      final uri = await _ensureWidgetVerseUri(raw);
      WidgetsBinding.instance.addPostFrameCallback((_) => handleUri(uri));
    } catch (_) {}
  }

  static StreamSubscription<Uri?>? subscribeWidgetClicks() {
    if (kIsWeb || !Platform.isAndroid) return null;
    return HomeWidget.widgetClicked.listen((Uri? uri) {
      Future.microtask(() async {
        final u = await _ensureWidgetVerseUri(uri);
        WidgetsBinding.instance.addPostFrameCallback((_) => handleUri(u));
      });
    });
  }
}
