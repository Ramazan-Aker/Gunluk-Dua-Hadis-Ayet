import 'package:daily_dua_hadith/main.dart' as app;
import 'package:daily_dua_hadith/screens/quran_listening_screen.dart';
import 'package:daily_dua_hadith/screens/prayer_alarm_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('App startup, tabs, listening route and prayer alarm route',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final asked = prefs.getBool('notification_permission_asked');
    await prefs.setBool('notification_permission_asked', true);
    addTearDown(() async {
      if (asked == null) {
        await prefs.remove('notification_permission_asked');
      } else {
        await prefs.setBool('notification_permission_asked', asked);
      }
    });
    app.main();
    Future<void> waitFor(Finder finder) async {
      for (var i = 0; i < 150 && finder.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(finder, findsWidgets);
    }

    await waitFor(find.byType(MaterialApp));
    await tester.pump(const Duration(seconds: 3));
    if (find.text('Atla').evaluate().isNotEmpty) {
      await tester.tap(find.text('Atla'));
    }
    await waitFor(find.byType(BottomNavigationBar));
    await tester.pump(const Duration(seconds: 3));
    // Dismiss the app's informational daily reminder, if shown.
    if (find.text('Okudum').evaluate().isNotEmpty &&
        find.byType(Dialog).evaluate().isNotEmpty) {
      await tester.tap(find.text('Okudum'));
      await tester.pump(const Duration(seconds: 1));
    }
    final nav = find.byType(BottomNavigationBar);
    Future<void> tab(String name) async {
      debugPrint('QA navigation: $name');
      await tester.tap(find.descendant(of: nav, matching: find.text(name)));
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    }

    await tab("Kur'an");
    await tester.tap(find.text('Kur’an dinleme modu'));
    await waitFor(find.byType(QuranListeningScreen));
    await tester.pump(const Duration(seconds: 1));
    await tester.pageBack();
    await tester.pump(const Duration(seconds: 1));
    await tab('Namaz');
    final citySearch = find.byWidgetPredicate((widget) =>
        widget is TextField && widget.decoration?.hintText == 'Şehir ara...');
    if (citySearch.evaluate().isNotEmpty) {
      await tester.enterText(citySearch, 'İstanbul');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byWidgetPredicate(
          (widget) => widget is Text && widget.data == 'İstanbul'));
      await tester.pump(const Duration(seconds: 2));
    }
    final alarm = find.byTooltip('Namaz alarmlarını düzenle');
    await waitFor(alarm);
    await tester.tap(alarm);
    await waitFor(find.byType(PrayerAlarmScreen));
    await tester.pump(const Duration(seconds: 1));
    await tester.pageBack();
    await tester.pump(const Duration(seconds: 1));
    await tab('Mesajlar');
    await tab('Diğer');
    await tab('Ana Sayfa');
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
