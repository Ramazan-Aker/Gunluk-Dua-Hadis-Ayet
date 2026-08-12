import 'package:daily_dua_hadith/screens/smart_goal_reminder_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('hatırlatma ayarları küçük ekranda taşmadan gösterilir',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: SmartGoalReminderScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Akıllı Hatırlatmalar'), findsOneWidget);
    expect(find.text('Namaz hedefi'), findsOneWidget);
    expect(find.text('21:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
