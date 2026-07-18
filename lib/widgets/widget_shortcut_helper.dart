import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/home_screen_widget_service.dart';

/// Ana ekran / Kur'an / Mesajlar app bar'da ortak widget ekleme kısayolu.
class WidgetShortcutHelper {
  WidgetShortcutHelper._();

  static Future<void> offerPinWidget(BuildContext context) async {
    if (kIsWeb || !Platform.isAndroid) return;
    final supported = await HomeScreenWidgetService.isPinWidgetSupported();
    if (!context.mounted) return;
    if (supported) {
      await HomeScreenWidgetService.requestPinWidgetFromApp();
      return;
    }
    await HomeScreenWidgetService.syncRandomVerseForWidget();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ana ekrana widget ekleyin'),
        content: const Text(
          'Ana ekranda boş bir yere basılı tutun → "Widget\'lar" → '
          '"Her Gün İslam" uygulamasından günlük ayet widget\'ını sürükleyip bırakın. '
          'Ayetler Türkçe meal olarak rastgele seçilir ve birkaç saatte bir yenilenir.',
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
    if (kIsWeb || !Platform.isAndroid) return const [];
    return [
      IconButton(
        tooltip: 'Ana ekrana widget',
        icon: const Icon(Icons.widgets_outlined),
        onPressed: () => offerPinWidget(context),
      ),
    ];
  }
}
