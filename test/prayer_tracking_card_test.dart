import 'package:daily_dua_hadith/models/prayer_tracking.dart';
import 'package:daily_dua_hadith/theme/app_theme.dart';
import 'package:daily_dua_hadith/widgets/prayer_tracking_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PrayerTrackingSummary summary({bool paused = false}) {
    final today = DateTime(2026, 8, 10);
    final week = List.generate(7, (index) {
      final date = today.add(Duration(days: index));
      return PrayerTrackingDay(
        date: date,
        completed: index == 0
            ? {TrackedPrayer.sabah, TrackedPrayer.ogle}
            : const <TrackedPrayer>{},
        goal: 5,
        isPaused: index == 0 && paused,
      );
    });
    return PrayerTrackingSummary(
      today: week.first,
      week: week,
      currentStreak: 3,
      longestStreak: 7,
      defaultGoal: 5,
    );
  }

  Widget buildCard({
    bool paused = false,
    ValueChanged<TrackedPrayer>? onPrayerToggled,
  }) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: PrayerTrackingCard(
            summary: summary(paused: paused),
            onPrayerToggled: onPrayerToggled ?? (_) {},
            onGoalChanged: (_) {},
            onPauseChanged: (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('küçük ekranda takip kartı taşmadan gösterilir', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildCard());
    await tester.pumpAndSettle();

    expect(find.text('Namaz Takibi'), findsOneWidget);
    expect(find.text('Sabah'), findsOneWidget);
    expect(find.text('Yatsı'), findsOneWidget);
    expect(find.text('2/5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('namaz seçimi geri çağrıyı çalıştırır', (tester) async {
    TrackedPrayer? selected;
    await tester.pumpWidget(
      buildCard(onPrayerToggled: (prayer) => selected = prayer),
    );

    await tester.tap(find.text('İkindi'));
    expect(selected, TrackedPrayer.ikindi);
  });

  testWidgets('duraklatılmış görünüm devam seçeneğini gösterir',
      (tester) async {
    await tester.pumpWidget(buildCard(paused: true));

    expect(find.text('Takip bugün duraklatıldı'), findsOneWidget);
    expect(find.text('Devam et'), findsOneWidget);
    expect(find.text('Sabah'), findsNothing);
  });
}
