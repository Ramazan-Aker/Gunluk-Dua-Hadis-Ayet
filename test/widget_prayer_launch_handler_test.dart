import 'package:flutter_test/flutter_test.dart';
import 'package:daily_dua_hadith/widget_prayer_pending.dart';
import 'package:daily_dua_hadith/widget_verse_launch_handler.dart';

void main() {
  tearDown(() {
    pendingPrayerWidgetOpen.value = false;
  });

  test('namaz widget bağlantısı Namaz sekmesini beklemeye alır', () {
    WidgetVerseLaunchHandler.handleUri(Uri.parse('hergunislam://prayer'));

    expect(pendingPrayerWidgetOpen.value, isTrue);
  });
}
