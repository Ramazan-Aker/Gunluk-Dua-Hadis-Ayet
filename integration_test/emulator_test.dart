import 'dart:convert';
import 'dart:io';

import 'package:daily_dua_hadith/models/prayer_alarm_rule.dart';
import 'package:daily_dua_hadith/models/prayer_times.dart';
import 'package:daily_dua_hadith/screens/prayer_alarm_screen.dart';
import 'package:daily_dua_hadith/screens/quran_listening_screen.dart';
import 'package:daily_dua_hadith/services/app_update_service.dart';
import 'package:daily_dua_hadith/services/firebase_service.dart';
import 'package:daily_dua_hadith/services/notification_service.dart';
import 'package:daily_dua_hadith/services/prayer_alarm_service.dart';
import 'package:daily_dua_hadith/services/quran_listening_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Future<void> waitUntil(WidgetTester tester, bool Function() ready,
      {int seconds = 40}) async {
    final end = DateTime.now().add(Duration(seconds: seconds));
    while (!ready() && DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(ready(), isTrue, reason: 'Timed out waiting for native player');
  }

  Future<void> screenshot(WidgetTester tester, String name) async {
    await tester.pump();
    final bytes = await binding.takeScreenshot(name);
    final dir = await getExternalStorageDirectory();
    if (dir != null) {
      final output = Directory('${dir.path}/qa');
      await output.create(recursive: true);
      await File('${output.path}/$name.png').writeAsBytes(bytes);
    }
  }

  testWidgets('Firebase native connection and published disabled policies',
      (tester) async {
    await FirebaseService.initialize();
    expect(Firebase.app().options.projectId, 'gunluk-dua-hadis-15178');
    final config = FirebaseRemoteConfig.instance;
    await config.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 20),
        minimumFetchInterval: Duration.zero));
    await config.fetchAndActivate();
    expect(config.lastFetchStatus, RemoteConfigFetchStatus.success);
    for (final key in [AppUpdateService.androidKey, AppUpdateService.iosKey]) {
      expect(config.getValue(key).source, ValueSource.valueRemote);
      expect(jsonDecode(config.getString(key))['enabled'], false);
    }
    expect(await AppUpdateService().check(), isNull);
    await FirebaseService.logEvent(
        name: 'qa_emulator_verified',
        parameters: {'test_run': '20260904', 'result': 'connected'});
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Real Quran stream, pause/resume, repeats and next chapter',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final savedBookmark = prefs.getString('quran_listen_bookmark');
    final savedAuto = prefs.getBool('quran_listen_auto_next');
    final handler = await QuranListening.initialize();
    addTearDown(() async {
      await handler.stop();
      if (savedBookmark == null) {
        await prefs.remove('quran_listen_bookmark');
      } else {
        await prefs.setString('quran_listen_bookmark', savedBookmark);
      }
      if (savedAuto == null) {
        await prefs.remove('quran_listen_auto_next');
      } else {
        await prefs.setBool('quran_listen_auto_next', savedAuto);
      }
    });
    await tester
        .pumpWidget(MaterialApp(home: QuranListeningScreen(handler: handler)));
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    await handler.openChapter(112, autoplay: false);
    expect(handler.error, isNull);
    expect(handler.chapter, 112);
    expect(handler.recitation!.timings.length, 4);
    await handler.play();
    await waitUntil(tester, () => handler.position.inMilliseconds > 1200);
    await handler.pause();
    final paused = handler.position;
    await tester.pump(const Duration(milliseconds: 600));
    expect((handler.position - paused).inMilliseconds.abs(), lessThan(200));
    await handler.play();
    await waitUntil(tester, () => handler.position > paused);
    await screenshot(tester, 'listening_playing');
    for (final count in [3, 5, 10]) {
      await handler.repeatVerse(1, count);
      expect(handler.error, isNull);
      for (var remaining = count; remaining > 0; remaining--) {
        await waitUntil(tester, () => handler.player.duration != null);
        final clipDuration = handler.player.duration!;
        await handler.seek(clipDuration - const Duration(milliseconds: 200));
        await waitUntil(tester, () => handler.repeatsLeft == remaining - 1);
      }
      expect(handler.player.playing, false);
      expect(handler.chapter, 112);
    }
    await handler.openChapter(113, autoplay: false);
    await handler.setAutoNext(true);
    await handler
        .seek(handler.player.duration! - const Duration(milliseconds: 300));
    await handler.play();
    await waitUntil(tester, () => handler.chapter == 114 && !handler.busy);
    expect(handler.error, isNull);
    await handler.pause();
    await handler.seek(const Duration(seconds: 3));
    await handler.saveBookmark();
    expect(
        ListeningBookmark.parse(prefs.getString('quran_listen_bookmark'))!
            .chapter,
        114);
    expect(find.byIcon(Icons.download), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Native alarm queue preserves Friday/noon and Monday/fajr cities',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final service = PrayerAlarmService();
    final original = await service.loadRules();
    final istanbul =
        PrayerAlarmService.cities.firstWhere((c) => c.name == 'İstanbul');
    final ankara =
        PrayerAlarmService.cities.firstWhere((c) => c.name == 'Ankara');
    final rules = [
      PrayerAlarmRule(
          id: 'qa_friday',
          city: istanbul,
          weekdays: {5},
          prayers: {AlarmPrayer.dhuhr}),
      PrayerAlarmRule(
          id: 'qa_monday',
          city: ankara,
          weekdays: {1},
          prayers: {AlarmPrayer.fajr}),
    ];
    final cache = {
      for (final c in [istanbul, ankara])
        c.id: prefs.getString('prayer_alarm_times_${c.id}')
    };
    addTearDown(() async {
      await service.saveRules(original);
      for (final entry in cache.entries) {
        final key = 'prayer_alarm_times_${entry.key}';
        if (entry.value == null) {
          await prefs.remove(key);
        } else {
          await prefs.setString(key, entry.value!);
        }
      }
      await service.refresh(force: true);
    });
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final days = [
      for (var i = 0; i < 14; i++)
        PrayerTimes(
            date: tomorrow.add(Duration(days: i)),
            imsak: '05:10',
            gunes: '06:35',
            ogle: '13:05',
            ikindi: '16:40',
            aksam: '19:30',
            yatsi: '20:50')
    ];
    await service.saveRules(rules);
    final count = await service
        .refresh(force: true, knownTimes: {istanbul.id: days, ankara.id: days});
    expect(count, 4);
    final pending = (await NotificationService().getPendingNotifications())
        .where((n) => n.id >= 10000 && n.id <= 10059)
        .toList();
    expect(pending.length, 4);
    expect(
        pending
            .where((n) =>
                n.body!.contains('İstanbul') && n.title!.contains('Öğle'))
            .length,
        2);
    expect(
        pending
            .where(
                (n) => n.body!.contains('Ankara') && n.title!.contains('Sabah'))
            .length,
        2);
    await tester.pumpWidget(
        MaterialApp(home: PrayerAlarmScreen(initialCity: istanbul)));
    await tester.pumpAndSettle();
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    await screenshot(tester, 'alarm_rules');
    expect(tester.takeException(), isNull);
  });
}
