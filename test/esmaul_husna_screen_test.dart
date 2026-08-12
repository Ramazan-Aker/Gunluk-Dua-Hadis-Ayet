import 'package:daily_dua_hadith/screens/esmaul_husna_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Esmaül Hüsna küçük telefonda taşmadan gösterilir',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: EsmaulHusnaScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Esmaül Hüsna'), findsOneWidget);
    expect(find.text('Allah’ın 99 Güzel İsmi'), findsOneWidget);
    expect(find.text('Allah'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('arama aksansız yazımla ismi bulur', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: EsmaulHusnaScreen()),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'rahman');
    await tester.pump();

    expect(find.text('Er-Rahmân'), findsOneWidget);
    expect(find.text('Es-Sabûr'), findsNothing);
  });
}
