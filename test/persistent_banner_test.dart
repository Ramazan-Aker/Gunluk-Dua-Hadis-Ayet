import 'package:daily_dua_hadith/main.dart';
import 'package:daily_dua_hadith/services/ad_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('üst ve alt bannerlar sekme değişiminde yeniden oluşturulmaz',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => PersistentTopBannerShell(child: child!),
        home: const MainNavigationScreen(),
      ),
    );
    await tester.pump();

    final bannerFinder = find.byKey(
      const ValueKey<String>('persistent-main-banner'),
    );
    final topBannerFinder = find.byKey(
      const ValueKey<String>('persistent-top-banner'),
    );
    expect(bannerFinder, findsOneWidget);
    expect(topBannerFinder, findsOneWidget);
    expect(find.byType(AdBannerWidget), findsNWidgets(2));
    final initialState = tester.state(bannerFinder);
    final initialTopState = tester.state(topBannerFinder);

    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pump();

    expect(bannerFinder, findsOneWidget);
    expect(find.byType(AdBannerWidget), findsNWidgets(2));
    expect(tester.state(bannerFinder), same(initialState));
    expect(tester.state(topBannerFinder), same(initialTopState));

    await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
    await tester.pump();
    expect(find.byType(AdBannerWidget), findsNWidgets(2));
    expect(tester.state(bannerFinder), same(initialState));
    expect(tester.state(topBannerFinder), same(initialTopState));

    final topLayout = tester.widget<Stack>(
      find.byKey(const ValueKey<String>('persistent-top-banner-layout')),
    );
    expect(topLayout.children.first, isA<Positioned>());
    expect(topLayout.children.last, isA<CompositedTransformFollower>());

    final slotFinder = find.byKey(
      const ValueKey<String>('persistent-top-banner-slot'),
    );
    expect(slotFinder, findsOneWidget);
    expect(
      tester.getSize(slotFinder).height,
      TopBannerAdBody.bannerSlotHeight,
    );
    expect(
      tester.getTopLeft(slotFinder).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(find.byType(AppBar)).dy),
    );

    // Ana sayfanın gecikmeli hatırlatma kontrolünü tamamlayıp ağacı temizle.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
