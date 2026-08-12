import 'package:daily_dua_hadith/services/app_review_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeReviewGateway implements AppReviewGateway {
  bool available = true;
  int requestCount = 0;
  String? openedAppStoreId;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async => requestCount++;

  @override
  Future<void> openStoreListing({String? appStoreId}) async {
    openedAppStoreId = appStoreId;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('yeterli kullanım oluşmadan değerlendirme istenmez', () async {
    final gateway = _FakeReviewGateway();
    final service = AppReviewService(gateway: gateway);
    final now = DateTime(2026, 8, 12);

    await service.registerLaunch(now: now);
    await service.registerMeaningfulActionAndMaybeRequest(now: now);

    expect(gateway.requestCount, 0);
  });

  test('anlamlı kullanımdan sonra yerel değerlendirme penceresi istenir',
      () async {
    final gateway = _FakeReviewGateway();
    final service = AppReviewService(gateway: gateway);
    final firstUse = DateTime(2026, 8, 1);

    for (var i = 0; i < AppReviewService.minimumLaunchCount; i++) {
      await service.registerLaunch(now: firstUse.add(Duration(days: i)));
    }
    for (var i = 0; i < AppReviewService.minimumMeaningfulActionCount; i++) {
      await service.registerMeaningfulActionAndMaybeRequest(
        now: firstUse.add(const Duration(days: 5)),
      );
    }

    expect(gateway.requestCount, 1);
  });

  test('bekleme süresi dolmadan tekrar değerlendirme istenmez', () async {
    final gateway = _FakeReviewGateway();
    final service = AppReviewService(gateway: gateway);
    final firstUse = DateTime(2026, 1, 1);

    for (var i = 0; i < AppReviewService.minimumLaunchCount; i++) {
      await service.registerLaunch(now: firstUse);
    }
    for (var i = 0; i < AppReviewService.minimumMeaningfulActionCount; i++) {
      await service.registerMeaningfulActionAndMaybeRequest(
        now: firstUse.add(const Duration(days: 4)),
      );
    }
    await service.registerMeaningfulActionAndMaybeRequest(
      now: firstUse.add(const Duration(days: 30)),
    );

    expect(gateway.requestCount, 1);
  });

  test('mağaza düğmesi App Store kimliğini kullanır', () async {
    final gateway = _FakeReviewGateway();

    await AppReviewService(gateway: gateway).openStoreListing();

    expect(gateway.openedAppStoreId, AppReviewService.appStoreId);
  });
}
