import 'package:daily_dua_hadith/screens/dhikr_counter_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('zikirmatik küçük ekranda açılır ve sayaç anında artar',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: DhikrCounterScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Zikirmatik'), findsOneWidget);
    expect(find.text('0'), findsWidgets);

    await tester.tap(
      find.bySemanticsLabel('Sübhanallah sayacını artır'),
    );
    await tester.pump();

    expect(find.text('1'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
