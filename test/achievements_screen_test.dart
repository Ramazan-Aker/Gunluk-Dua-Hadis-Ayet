import 'package:daily_dua_hadith/screens/achievements_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('rozet ekranı küçük telefonda taşmadan gösterilir',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: AchievementsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Başarılar ve Rozetler'), findsOneWidget);
    expect(find.text('Rozet koleksiyonun'), findsOneWidget);
    expect(find.text('İlk Adım'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
