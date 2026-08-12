import 'package:flutter_tts/flutter_tts.dart';

class EsmaulHusnaAudioService {
  final FlutterTts _tts;
  bool _configured = false;

  EsmaulHusnaAudioService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  Future<void> speak(String turkishPronunciation) async {
    if (!_configured) {
      await _configureTurkishMaleVoice();
      await _tts.setVolume(1);
      await _tts.awaitSpeakCompletion(true);
      _configured = true;
    }
    await _tts.stop();
    final result = await _tts.speak(normalizeTurkishPronunciation(
      turkishPronunciation,
    ));
    if (result != 1) throw StateError('Sesli okuma başlatılamadı.');
  }

  Future<void> stop() => _tts.stop();

  Future<void> _configureTurkishMaleVoice() async {
    await _tts.setLanguage('tr-TR');
    await _tts.setSpeechRate(0.38);

    // Android TTS motorları sesin cinsiyetini her zaman bildirmez. iOS ise
    // `gender` alanını döndürür. Uygun erkek sesi bulunursa onu seçer,
    // bulunamazsa Türkçe varsayılan sesi daha tok bir perdeyle kullanırız.
    Map<String, String>? preferredVoice;
    try {
      final voices = await _tts.getVoices;
      preferredVoice = selectPreferredTurkishMaleVoice(voices);
      if (preferredVoice != null) {
        await _tts.setVoice(preferredVoice);
      }
    } catch (_) {
      // Bazı Android TTS motorları ses listesini paylaşmaz. Bu durumda
      // tr-TR dili ve düşük perdeyle cihazın varsayılan sesini kullanırız.
    }
    await _tts.setPitch(
      preferredVoice != null && _isMaleVoice(preferredVoice) ? 0.9 : 0.78,
    );
  }

  static Map<String, String>? selectPreferredTurkishMaleVoice(
    dynamic availableVoices,
  ) {
    if (availableVoices is! List) return null;

    final turkishVoices = availableVoices
        .whereType<Map>()
        .map(
          (voice) => voice.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ),
        )
        .where((voice) => _isTurkishLocale(voice['locale']))
        .toList();
    final usableVoices = turkishVoices.where((voice) {
      final gender = voice['gender']?.toLowerCase();
      return gender != 'female' && gender != 'kadın';
    }).toList();
    if (usableVoices.isEmpty) return null;

    usableVoices.sort(
      (left, right) => _voiceScore(right).compareTo(_voiceScore(left)),
    );
    return usableVoices.first;
  }

  static String normalizeTurkishPronunciation(String value) => value
      .replaceAll('-', ' ')
      .replaceAll(RegExp("[’‘'ʼ]"), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static bool _isTurkishLocale(String? locale) {
    final normalized = locale?.replaceAll('_', '-').toLowerCase();
    return normalized == 'tr' || normalized?.startsWith('tr-') == true;
  }

  static int _voiceScore(Map<String, String> voice) {
    final gender = voice['gender']?.toLowerCase() ?? '';
    final quality = voice['quality']?.toLowerCase() ?? '';
    final locale = voice['locale']?.replaceAll('_', '-').toLowerCase() ?? '';
    var score = locale == 'tr-tr' ? 40 : 20;

    if (gender == 'male' || gender == 'erkek') {
      score += 1000;
    } else if (gender == 'female' || gender == 'kadın') {
      score -= 500;
    }

    if (quality.contains('premium')) {
      score += 30;
    } else if (quality.contains('enhanced')) {
      score += 20;
    }
    if (voice['network_required'] == '0') score += 5;
    return score;
  }

  static bool _isMaleVoice(Map<String, String> voice) {
    final gender = voice['gender']?.toLowerCase() ?? '';
    final name = voice['name']?.toLowerCase() ?? '';
    return gender == 'male' ||
        gender == 'erkek' ||
        name.contains(' male') ||
        name.contains('erkek');
  }
}
