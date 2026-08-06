import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/home_screen_widget_service.dart';

/// Ana ekran / Kur'an / Mesajlar app bar'da ortak widget ekleme kısayolu.
class WidgetShortcutHelper {
  WidgetShortcutHelper._();

  static Future<void> offerPinWidget(BuildContext context) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;

    if (Platform.isAndroid) {
      final supported = await HomeScreenWidgetService.isPinWidgetSupported();
      if (!context.mounted) return;
      if (supported) {
        await HomeScreenWidgetService.requestPinWidgetFromApp();
        return;
      }
    }

    await HomeScreenWidgetService.syncRandomVerseForWidget();
    if (!context.mounted) return;

    final instructions = Platform.isIOS
        ? 'iPhone ana ekranında boş bir yere basılı tutun → sol üstteki “+” '
            'simgesine dokunun → “Her Gün İslam”ı arayın → küçük, orta veya '
            'büyük boyutu seçip “Widget Ekle”ye dokunun.'
        : 'Ana ekranda boş bir yere basılı tutun → “Widget\'lar” → '
            '“Her Gün İslam” uygulamasından günlük ayet widget\'ını sürükleyip bırakın.';

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.widgets_rounded),
        title: const Text('Günlük ayeti ana ekrana ekleyin'),
        content: Text(
          '$instructions\n\nWidget’a dokunduğunuzda ilgili ayet Kur’an ekranında açılır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  static List<Widget> appBarActions(BuildContext context) {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return const [];
    return [
      IconButton(
        tooltip: 'Ana ekrana widget',
        icon: const Icon(Icons.widgets_outlined),
        onPressed: () => offerPinWidget(context),
      ),
    ];
  }
}
