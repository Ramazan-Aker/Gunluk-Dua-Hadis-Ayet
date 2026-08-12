import 'package:daily_dua_hadith/screens/qibla_screen.dart';
import 'package:daily_dua_hadith/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('kıble tanıtımı küçük ekranda seçenekleri gösterir',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const QiblaScreen(
          fallbackCityName: 'İstanbul',
          autoStart: false,
        ),
      ),
    );

    expect(find.text('Kıbleyi Bul'), findsOneWidget);
    expect(find.text('Konumumu kullan'), findsOneWidget);
    expect(find.text('İstanbul merkezini kullan'), findsOneWidget);
    expect(find.text('Konum kaydedilmez veya paylaşılmaz'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
