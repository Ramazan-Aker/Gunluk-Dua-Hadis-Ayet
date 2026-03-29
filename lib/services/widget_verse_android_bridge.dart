import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../widget_verse_pending.dart';

/// Widget tıklamasında native [Intent] extra ile gelen hatim indeksini okur (home_widget URI’sine bağlı değil).
class WidgetVerseAndroidBridge {
  WidgetVerseAndroidBridge._();

  static const MethodChannel _channel =
      MethodChannel('com.tahram.gunlukduahadis/widget_verse');

  static Future<void> consumeAndDispatchToFlutter() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final raw = await _channel.invokeMethod<dynamic>('consumePendingVerseListIndex');
      final idx = _parseIndex(raw);
      if (idx == null || idx < 0) return;
      pendingWidgetVerseListIndex.value = null;
      pendingWidgetVerseListIndex.value = idx;
    } catch (_) {}
  }

  static int? _parseIndex(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString());
  }
}
