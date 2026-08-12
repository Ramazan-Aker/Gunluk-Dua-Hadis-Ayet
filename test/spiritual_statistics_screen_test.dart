import 'package:daily_dua_hadith/screens/spiritual_statistics_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('istatistik ekranı küçük telefonda taşmadan gösterilir',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: SpiritualStatisticsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Manevi İstatistikler'), findsOneWidget);
    expect(find.text('Son 7 günün özeti'), findsOneWidget);
    expect(find.text('Namaz'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('30 günlük görünüm seçilebilir', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SpiritualStatisticsScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('30 Gün'));
    await tester.pumpAndSettle();

    expect(find.text('Son 30 günün özeti'), findsOneWidget);
  });
}
