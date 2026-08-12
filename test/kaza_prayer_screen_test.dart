import 'package:daily_dua_hadith/screens/kaza_prayer_screen.dart';
import 'package:daily_dua_hadith/models/kaza_prayer_tracking.dart';
import 'package:daily_dua_hadith/services/kaza_prayer_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('kaza namazı ekranı küçük telefonda taşmadan gösterilir',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: KazaPrayerScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Kaza Namazı Takibi'), findsOneWidget);
    expect(find.text('Toplam kaza borcu'), findsOneWidget);
    expect(find.text('Sabah'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('borç ekleme formu açılır', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: KazaPrayerScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kaza borcu ekle'));
    await tester.pumpAndSettle();

    expect(find.text('Adet'), findsOneWidget);
    expect(find.text('Borcu ekle'), findsOneWidget);
  });

  testWidgets('tamamlanan kaza hareketi tarihçede gösterilir', (tester) async {
    final service = KazaPrayerService();
    await service.addDebt(KazaPrayerType.fajr, 1);
    await service.markPerformed(KazaPrayerType.fajr);

    await tester.pumpWidget(const MaterialApp(home: KazaPrayerScreen()));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -1500));
    await tester.pumpAndSettle();

    expect(find.text('Kılındı'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
