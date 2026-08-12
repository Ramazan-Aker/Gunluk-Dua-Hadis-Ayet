import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/home_screen_widget_service.dart';
import '../services/prayer_home_widget_service.dart';
import '../theme/app_theme.dart';

enum _HomeWidgetChoice { verse, prayer }

/// Ana ekran / Kur'an / Mesajlar app bar'ında ortak widget ekleme kısayolu.
class WidgetShortcutHelper {
  WidgetShortcutHelper._();

  static Future<void> offerPinWidget(BuildContext context) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;

    final choice = await showModalBottomSheet<_HomeWidgetChoice>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.ivory,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ana ekran widget’ı',
                  style: TextStyle(
                      color: AppTheme.navy,
                      fontSize: 21,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              const Text('Eklemek istediğin widget’ı seç.',
                  style: TextStyle(color: AppTheme.textMuted)),
              const SizedBox(height: 18),
              _choiceTile(
                context: sheetContext,
                choice: _HomeWidgetChoice.prayer,
                icon: Icons.mosque_rounded,
                title: 'Namaz vakitleri',
                subtitle: 'Sıradaki namaz, kalan süre ve günlük vakitler',
              ),
              const SizedBox(height: 10),
              _choiceTile(
                context: sheetContext,
                choice: _HomeWidgetChoice.verse,
                icon: Icons.auto_stories_rounded,
                title: 'Günün ayeti',
                subtitle: 'Gün içinde yenilenen ayet kartı',
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !context.mounted) return;

    if (Platform.isAndroid) {
      final supported = await HomeScreenWidgetService.isPinWidgetSupported();
      if (!context.mounted) return;
      if (supported) {
        if (choice == _HomeWidgetChoice.prayer) {
          await PrayerHomeWidgetService.refreshWidget();
          await PrayerHomeWidgetService.requestPinWidgetFromApp();
        } else {
          await HomeScreenWidgetService.syncRandomVerseForWidget();
          await HomeScreenWidgetService.requestPinWidgetFromApp();
        }
        return;
      }
    }

    if (choice == _HomeWidgetChoice.verse) {
      await HomeScreenWidgetService.syncRandomVerseForWidget();
    } else {
      await PrayerHomeWidgetService.refreshWidget();
    }
    if (!context.mounted) return;

    final widgetName =
        choice == _HomeWidgetChoice.prayer ? 'Namaz Vakitleri' : 'Günün Ayeti';
    final instructions = Platform.isIOS
        ? 'iPhone ana ekranında boş bir yere basılı tut → sol üstteki “+” '
            'simgesine dokun → “Her Gün İslam”ı ara → “$widgetName” '
            'widget’ını seçip “Widget Ekle”ye dokun.'
        : 'Ana ekranda boş bir yere basılı tut → “Widget’lar” → '
            '“Her Gün İslam” → “$widgetName” widget’ını sürükleyip bırak.';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(choice == _HomeWidgetChoice.prayer
            ? Icons.mosque_rounded
            : Icons.auto_stories_rounded),
        title: Text('$widgetName widget’ını ekle'),
        content: Text(
          choice == _HomeWidgetChoice.prayer
              ? '$instructions\n\nNamaz vakitlerinin hazırlanması için Namaz ekranında bir şehir seçilmiş olmalı.'
              : '$instructions\n\nWidget’a dokunduğunda ilgili ayet Kur’an ekranında açılır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  static Widget _choiceTile({
    required BuildContext context,
    required _HomeWidgetChoice choice,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pop(context, choice),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.mint,
                child: Icon(icon, color: AppTheme.emerald),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: AppTheme.navy, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: AppTheme.gold),
            ],
          ),
        ),
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
