import 'package:daily_dua_hadith/models/share_format.dart';
import 'package:daily_dua_hadith/services/ready_message_preferences_service.dart';
import 'package:daily_dua_hadith/services/ready_message_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('yerel hazır mesaj kataloğu ve tüm görseller yüklenir', () async {
    final designs = await ReadyMessageService().loadDesigns();

    expect(designs, hasLength(270));
    expect(designs.map((design) => design.id).toSet(), hasLength(270));
    expect(designs.map((design) => design.category), contains('cuma'));
    expect(designs.map((design) => design.category), contains('dua'));
    expect(designs.map((design) => design.category), contains('cesaret'));
    expect(designs.where((design) => design.category == 'mevlid'), hasLength(10));
    expect(designs.where((design) => design.category == 'regaib'), hasLength(10));
    expect(designs.where((design) => design.category == 'mirac'), hasLength(10));
    expect(designs.where((design) => design.category == 'berat'), hasLength(10));
    expect(designs.where((design) => design.category == 'kadir'), hasLength(10));
    expect(
      designs.where((design) => design.category == 'ramazan_bayrami'),
      hasLength(10),
    );
    expect(
      designs.where((design) => design.category == 'kurban_bayrami'),
      hasLength(10),
    );
    expect(
      designs.where((design) => design.sourceUrl != null),
      hasLength(257),
    );

    for (final design in designs) {
      final background = await rootBundle.load(design.backgroundAssetPath);
      expect(
        background.lengthInBytes,
        greaterThan(0),
        reason: design.backgroundAssetPath,
      );
    }
  });

  test('paylaşım formatları sosyal medya ölçülerini korur', () {
    expect((ShareFormat.story.width, ShareFormat.story.height), (1080, 1920));
    expect((ShareFormat.feed.width, ShareFormat.feed.height), (1080, 1350));
    expect((ShareFormat.square.width, ShareFormat.square.height), (1080, 1080));
    expect(ShareFormat.story.aspectRatio, 9 / 16);
    expect(ShareFormat.feed.aspectRatio, 4 / 5);
    expect(ShareFormat.square.aspectRatio, 1);
  });

  test('hazır tasarım favorileri cihazda saklanır', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = ReadyMessagePreferencesService();

    expect(await preferences.loadFavoriteIds(), isEmpty);
    expect(await preferences.toggleFavorite('cuma_001'), {'cuma_001'});
    expect(await preferences.loadFavoriteIds(), {'cuma_001'});
    expect(await preferences.toggleFavorite('cuma_001'), isEmpty);
  });
}
