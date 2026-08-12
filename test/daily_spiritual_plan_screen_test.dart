import 'package:daily_dua_hadith/screens/daily_spiritual_plan_screen.dart';
import 'package:daily_dua_hadith/services/daily_spiritual_plan_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('günlük plan küçük telefonda taşmadan gösterilir',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: DailySpiritualPlanScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Günlük Planım'), findsOneWidget);
    expect(find.text('Bugünkü hedefler'), findsOneWidget);
    expect(find.text('Günün içeriğini oku'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kişisel hedef ekranda tamamlanabilir', (tester) async {
    final service = DailySpiritualPlanService();
    for (final id in DailySpiritualPlanService.coreTaskIds) {
      await service.setCoreTaskEnabled(id, false);
    }
    await service.addCustomTask('Bir iyilik yap');

    await tester.pumpWidget(
      const MaterialApp(home: DailySpiritualPlanScreen()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bir iyilik yap'));
    await tester.pumpAndSettle();

    expect(find.text('Bugün tamamlandı'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kişisel hedef ekleme penceresi güvenle kapanır', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: DailySpiritualPlanScreen()),
    );
    await tester.pumpAndSettle();

    final addButton = find.text('Kişisel hedef ekle');
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Her gün dua et');
    await tester.tap(find.widgetWithText(FilledButton, 'Ekle'));
    await tester.pumpAndSettle();

    expect(find.text('Her gün dua et'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
