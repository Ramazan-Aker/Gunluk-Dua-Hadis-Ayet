import 'package:daily_dua_hadith/services/esmaul_husna_audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Türkçe erkek sesi kadın sesine tercih edilir', () {
    final selected = EsmaulHusnaAudioService.selectPreferredTurkishMaleVoice([
      {
        'name': 'Yelda',
        'locale': 'tr-TR',
        'gender': 'female',
        'quality': 'enhanced',
      },
      {
        'name': 'Cem',
        'locale': 'tr-TR',
        'gender': 'male',
        'quality': 'default',
      },
    ]);

    expect(selected?['name'], 'Cem');
  });

  test('Türkçe dışındaki erkek sesleri kullanılmaz', () {
    final selected = EsmaulHusnaAudioService.selectPreferredTurkishMaleVoice([
      {'name': 'English Male', 'locale': 'en-US', 'gender': 'male'},
      {'name': 'Türkçe', 'locale': 'tr_TR'},
    ]);

    expect(selected?['name'], 'Türkçe');
  });

  test('Türkçe ses yoksa varsayılan sese geri dönülür', () {
    final selected = EsmaulHusnaAudioService.selectPreferredTurkishMaleVoice([
      {'name': 'Arabic', 'locale': 'ar-SA', 'gender': 'male'},
    ]);

    expect(selected, isNull);
  });

  test('yalnızca kadın sesi varsa daha tok varsayılan sese dönülür', () {
    final selected = EsmaulHusnaAudioService.selectPreferredTurkishMaleVoice([
      {'name': 'Yelda', 'locale': 'tr-TR', 'gender': 'female'},
    ]);

    expect(selected, isNull);
  });

  test('isimler Türkçe konuşma motoruna uygun hale getirilir', () {
    expect(
      EsmaulHusnaAudioService.normalizeTurkishPronunciation('El-Mü’min'),
      'El Mümin',
    );
  });
}
