import 'package:daily_dua_hadith/screens/religious_days_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dini günler ekranı küçük telefonda taşmaz', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: ReligiousDaysScreen()),
    );
    await tester.pump();

    expect(find.text('Dini Günler'), findsOneWidget);
    expect(find.text('Sıradaki dini gün'), findsOneWidget);
    expect(find.text('Manevi araçlar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
