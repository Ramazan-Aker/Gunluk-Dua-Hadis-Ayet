import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:daily_dua_hadith/main.dart';

void main() {
  testWidgets('DailyDuaApp açılır', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await tester.pumpWidget(const DailyDuaApp());
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
