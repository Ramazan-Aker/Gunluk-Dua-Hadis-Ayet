import 'package:daily_dua_hadith/screens/quran_reading_plan_screen.dart';
import 'package:daily_dua_hadith/services/quran_reading_plan_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('plan kurulum ekranı küçük telefonda taşmadan gösterilir',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: QuranReadingPlanScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hatim Planım'), findsOneWidget);
    expect(find.text('Kendi hızında hatim yap'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('aktif plan günlük hedefi küçük telefonda gösterir',
      (tester) async {
    final now = DateTime.now();
    await QuranReadingPlanService().createPlan(
      targetDate: now.add(const Duration(days: 29)),
      now: now,
    );
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: QuranReadingPlanScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bugünün hedefi'), findsOneWidget);
    expect(find.textContaining('1 cüz'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
