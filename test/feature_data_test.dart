import 'package:daily_dua_hadith/models/quran_juz.dart';
import 'package:daily_dua_hadith/models/share_format.dart';
import 'package:daily_dua_hadith/services/religious_days_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('30 cüzün başlangıçları sıralı ve temel sınırlar doğru', () {
    expect(quranJuzList, hasLength(30));
    expect(quranJuzList.first.number, 1);
    expect(quranJuzList.first.startSurah, 1);
    expect(quranJuzList.first.startAyah, 1);
    expect(quranJuzList[1].startSurah, 2);
    expect(quranJuzList[1].startAyah, 142);
    expect(quranJuzList.last.startSurah, 78);
    expect(quranJuzList.last.startAyah, 1);
  });

  test('Diyanet 2027 bayram tarihleri düzeltilmiş', () {
    final days = ReligiousDaysService().getAllDays();
    final ramadan = days.singleWhere((day) => day.id == 'ramazan_bayrami_2027');
    final kurban = days.singleWhere((day) => day.id == 'kurban_bayrami_2027');
    expect(ramadan.date, DateTime(2027, 3, 9));
    expect(kurban.date, DateTime(2027, 5, 16));
  });

  test('Instagram paylaşım oranları doğru', () {
    expect(ShareFormat.feed.width, 1080);
    expect(ShareFormat.feed.height, 1350);
    expect(ShareFormat.story.width, 1080);
    expect(ShareFormat.story.height, 1920);
    expect(ShareFormat.square.aspectRatio, 1);
  });
}
