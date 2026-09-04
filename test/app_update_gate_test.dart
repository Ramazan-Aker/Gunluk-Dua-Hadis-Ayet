import 'dart:async';
import 'package:daily_dua_hadith/models/app_update_policy.dart';
import 'package:daily_dua_hadith/widgets/app_update_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const optional = AppUpdateDecision(latestVersion: '2.0.3', required: false);
const mandatory = AppUpdateDecision(latestVersion: '2.0.3', required: true);

Widget app(
        {required Future<AppUpdateDecision?> Function() check,
        Future<void> Function()? openStore,
        GlobalKey<NavigatorState>? navigator,
        VoidCallback? onTap,
        double textScale = 1}) =>
    MaterialApp(
      navigatorKey: navigator,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: AppUpdateGate(check: check, openStore: openStore, child: child!),
      ),
      home: Scaffold(
          body: Center(
              child: TextButton(
                  onPressed: onTap ?? () {}, child: const Text('Ana ekran')))),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Optional update can be postponed across launches',
      (tester) async {
    await tester.pumpWidget(app(check: () async => optional));
    await tester.pumpAndSettle();
    expect(find.text('Yeni sürüm hazır'), findsOneWidget);
    await tester.tap(find.text('Daha sonra'));
    await tester.pumpAndSettle();
    expect(find.text('Yeni sürüm hazır'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(check: () async => optional));
    await tester.pumpAndSettle();
    expect(find.text('Yeni sürüm hazır'), findsNothing);
  });

  testWidgets('An expired postponement shows the reminder again',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'update_prompt_dismissed_version_v1': '2.0.3',
      'update_prompt_dismissed_at_v1':
          DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
    });
    await tester.pumpWidget(app(check: () async => optional));
    await tester.pumpAndSettle();
    expect(find.text('Yeni sürüm hazır'), findsOneWidget);
  });

  testWidgets(
      'Required update ignores postponement, blocks routes and survives back',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'update_prompt_dismissed_version_v1': '2.0.3',
      'update_prompt_dismissed_at_v1': DateTime.now().toIso8601String(),
    });
    final navigator = GlobalKey<NavigatorState>();
    var taps = 0;
    await tester.pumpWidget(app(
        check: () async => mandatory,
        navigator: navigator,
        onTap: () => taps++));
    await tester.pumpAndSettle();
    expect(find.text('Daha sonra'), findsNothing);
    expect(find.text('Ana ekran').hitTestable(), findsNothing);
    unawaited(navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) =>
            const Scaffold(body: Center(child: Text('Widget bağlantısı'))))));
    await tester.pumpAndSettle();
    expect(find.text('Widget bağlantısı').hitTestable(), findsNothing);
    expect(find.text('Güncelleme gerekli').hitTestable(), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Güncelleme gerekli'), findsOneWidget);
    expect(taps, 0);
  });

  testWidgets('Opening the store does not bypass enforcement; rollback unlocks',
      (tester) async {
    AppUpdateDecision? decision = mandatory;
    var opened = 0;
    var taps = 0;
    await tester.pumpWidget(app(
        check: () async => decision,
        openStore: () async {
          opened++;
        },
        onTap: () => taps++));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Güncelle'));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(find.text('Güncelleme gerekli'), findsOneWidget);
    decision = null;
    await tester.tap(find.text('Tekrar kontrol et'));
    await tester.pumpAndSettle();
    expect(find.text('Güncelleme gerekli'), findsNothing);
    await tester.tap(find.text('Ana ekran'));
    expect(taps, 1);
  });

  testWidgets('Store failures are visible and allow another attempt',
      (tester) async {
    var attempts = 0;
    await tester.pumpWidget(app(
        check: () async => mandatory,
        openStore: () async {
          if (++attempts == 1) throw StateError('store unavailable');
        }));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Güncelle'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mağaza açılamadı'), findsOneWidget);
    await tester.tap(find.text('Güncelle'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.textContaining('Mağaza açılamadı'), findsNothing);
    expect(find.text('Güncelleme gerekli'), findsOneWidget);
  });

  testWidgets('An unavailable check does not block the app', (tester) async {
    var taps = 0;
    await tester.pumpWidget(app(
        check: () async => throw StateError('offline'), onTap: () => taps++));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana ekran'));
    expect(taps, 1);
    expect(find.text('Güncelleme gerekli'), findsNothing);
  });

  testWidgets('Small screens and large text can scroll to update',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(check: () async => mandatory, textScale: 2));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Güncelle'));
    await tester.pumpAndSettle();
    expect(find.text('Güncelle').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
