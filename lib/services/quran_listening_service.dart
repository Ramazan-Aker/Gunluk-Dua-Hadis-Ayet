import 'dart:async';
import 'dart:convert';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chapter_recitation.dart';
import '../models/verse_timing.dart';
import 'quran_audio_service.dart';
import 'quran_audio_engine.dart';
import 'quran_timing_service.dart';

class ListeningBookmark {
  const ListeningBookmark(this.chapter, this.positionMs);
  final int chapter;
  final int positionMs;
  static ListeningBookmark? parse(String? raw) {
    try {
      final json = jsonDecode(raw!);
      final chapter = json['chapter'] as int;
      final position = json['positionMs'] as int;
      if (chapter < 1 || chapter > 114 || position < 0) return null;
      return ListeningBookmark(chapter, position);
    } catch (_) {
      return null;
    }
  }
}

class QuranListening {
  static QuranListeningHandler? instance;
  static Future<QuranListeningHandler>? _initializing;
  static Future<QuranListeningHandler> initialize() =>
      _initializing ??= _initialize();
  static Future<QuranListeningHandler> _initialize() async {
    try {
      instance = await AudioService.init<QuranListeningHandler>(
          builder: QuranListeningHandler.new,
          config: const AudioServiceConfig(
              androidNotificationChannelId:
                  'com.tahram.gunlukduahadis.quran_audio',
              androidNotificationChannelName: 'Kur’an dinleme',
              androidNotificationOngoing: true));
      await (await AudioSession.instance)
          .configure(const AudioSessionConfiguration.speech());
      await instance!.restoreSettings();
      return instance!;
    } catch (_) {
      _initializing = null;
      rethrow;
    }
  }
}

/// One process-wide player; routes only observe it, never dispose it.
class QuranListeningHandler extends BaseAudioHandler {
  QuranListeningHandler(
      {QuranAudioEngine? player,
      Future<ChapterRecitationResult?> Function(int)? loadRecitation})
      : player = player ?? JustQuranAudioEngine(),
        loadRecitation = loadRecitation ?? _fetchRecitation {
    this.player.playerStateStream.listen((state) {
      _broadcast();
      if (state.playing &&
          state.processingState == ja.ProcessingState.completed &&
          !_changing &&
          error == null) {
        unawaited(_complete());
      }
    });
    this.player.playbackEventStream.listen((_) => _broadcast());
    this.player.errorStream.listen((error) {
      unawaited(_fail('Ses oynatılamadı. İnternet bağlantınızı kontrol edin.'));
    });
    this.player.positionStream.listen((_) {
      revision.value++;
      if (!_changing &&
          DateTime.now().difference(_lastSaved) >= const Duration(seconds: 5)) {
        unawaited(_savePosition());
      }
    });
  }
  final QuranAudioEngine player;
  final Future<ChapterRecitationResult?> Function(int) loadRecitation;
  static Future<ChapterRecitationResult?> _fetchRecitation(int number) =>
      QuranTimingService().fetchChapterRecitationWithAudio(
          chapterNumber: number, appReciterId: 7);
  final revision = ValueNotifier(0);
  ChapterRecitationResult? recitation;
  int? chapter;
  bool autoNext = true;
  int repeatCount = 1;
  int repeatsLeft = 0;
  VerseTiming? repeatedVerse;
  bool busy = false;
  String? error;
  int _operation = 0;
  bool _changing = false;
  bool _completing = false;
  DateTime _lastSaved = DateTime.fromMillisecondsSinceEpoch(0);
  ListeningBookmark? bookmark;
  String get title =>
      QuranAudioService.turkishSurahNames[chapter] ?? 'Kur’an dinleme';
  Duration get position =>
      player.position +
      Duration(milliseconds: repeatedVerse?.timestampFrom ?? 0);
  Duration get duration => Duration(
      milliseconds: recitation?.timings.lastOrNull?.timestampTo ??
          player.duration?.inMilliseconds ??
          0);
  int get currentVerse =>
      repeatedVerse?.verseNumber ??
      recitation?.timings
          .lastWhere((t) => t.timestampFrom <= position.inMilliseconds,
              orElse: () => recitation!.timings.first)
          .verseNumber ??
      1;

  Future<void> restoreSettings() async {
    final prefs = await SharedPreferences.getInstance();
    autoNext = prefs.getBool('quran_listen_auto_next') ?? true;
    bookmark =
        ListeningBookmark.parse(prefs.getString('quran_listen_bookmark'));
    revision.value++;
  }

  Future<void> setAutoNext(bool value) async {
    autoNext = value;
    revision.value++;
    await (await SharedPreferences.getInstance())
        .setBool('quran_listen_auto_next', value);
  }

  Future<void> openChapter(int number,
      {Duration start = Duration.zero, bool autoplay = true}) async {
    if (number < 1 || number > 114 || busy) return;
    final operation = ++_operation;
    busy = true;
    _changing = true;
    error = null;
    revision.value++;
    try {
      await _savePosition();
      await player.pause();
      final rec = await loadRecitation(number);
      if (operation != _operation) return;
      if (rec == null || !rec.hasSyncData) {
        throw StateError('Ses verisi alınamadı.');
      }
      if (rec.timings.any((t) =>
              t.surahNumber != number ||
              t.verseNumber < 1 ||
              t.timestampFrom < 0 ||
              t.timestampTo <= t.timestampFrom) ||
          rec.timings.map((t) => t.verseNumber).toSet().length !=
              rec.timings.length) {
        throw const FormatException('Geçersiz ayet zamanları.');
      }
      final source = Uri.parse(rec.audioUrl!);
      repeatedVerse = null;
      repeatCount = 1;
      repeatsLeft = 0;
      final max = rec.timings.last.timestampTo;
      final initial = start.isNegative || start.inMilliseconds >= max
          ? Duration.zero
          : start;
      await player.load(source, initialPosition: initial);
      if (operation != _operation) {
        await player.stop();
        return;
      }
      chapter = number;
      recitation = rec;
      mediaItem.add(MediaItem(
          id: '$number',
          title: title,
          album: 'Her Gün İslam',
          artist: 'Mişari Raşid el-Afasi',
          duration: duration));
      await _savePosition();
      if (autoplay) {
        unawaited(player.play().catchError(
            (Object e) => _fail('Ses başlatılamadı. Tekrar deneyin.')));
      }
    } catch (_) {
      chapter = null;
      recitation = null;
      mediaItem.add(null);
      await _fail(
          'Sure yüklenemedi. İnternet bağlantınızı kontrol edip tekrar deneyin.');
    } finally {
      busy = false;
      _changing = false;
      _broadcast();
    }
  }

  Future<void> repeatVerse(int verse, int count) async {
    if (busy || recitation == null || ![1, 3, 5, 10].contains(count)) return;
    final timing =
        recitation!.timings.where((t) => t.verseNumber == verse).firstOrNull;
    if (timing == null || timing.timestampTo <= timing.timestampFrom) return;
    _changing = true;
    busy = true;
    revision.value++;
    try {
      await player.pause();
      repeatCount = count;
      repeatsLeft = count;
      repeatedVerse = count == 1 ? null : timing;
      await player.setClip(
          start:
              count == 1 ? null : Duration(milliseconds: timing.timestampFrom),
          end: count == 1 ? null : Duration(milliseconds: timing.timestampTo));
      final item = mediaItem.value;
      if (item != null) mediaItem.add(item.copyWith(duration: player.duration));
      await player.seek(count == 1
          ? Duration(milliseconds: timing.timestampFrom)
          : Duration.zero);
      unawaited(player
          .play()
          .catchError((Object e) => _fail('Tekrar oynatılamadı.')));
    } catch (_) {
      await _fail('Ayet tekrarı başlatılamadı.');
    } finally {
      busy = false;
      _changing = false;
      _broadcast();
    }
  }

  Future<void> _complete() async {
    if (_completing || chapter == null) return;
    _completing = true;
    try {
      if (repeatedVerse != null) {
        if (repeatsLeft <= 0) return;
        repeatsLeft--;
        if (repeatsLeft > 0) {
          await player.seek(Duration.zero);
          unawaited(player
              .play()
              .catchError((Object e) => _fail('Ses oynatılamadı.')));
        } else {
          await pause();
        }
      } else if (autoNext && chapter! < 114) {
        await openChapter(chapter! + 1);
      } else {
        await pause();
      }
    } finally {
      _completing = false;
      revision.value++;
    }
  }

  Future<void> _fail(String message) async {
    error = message;
    await player.pause();
    _broadcast();
  }

  Future<void> _savePosition() async {
    if (chapter == null) return;
    _lastSaved = DateTime.now();
    bookmark = ListeningBookmark(chapter!, position.inMilliseconds);
    try {
      await (await SharedPreferences.getInstance()).setString(
          'quran_listen_bookmark',
          jsonEncode({
            'chapter': bookmark!.chapter,
            'positionMs': bookmark!.positionMs
          }));
    } catch (_) {}
  }

  Future<void> saveBookmark() => _savePosition();
  @override
  Future<void> play() async {
    if (busy || chapter == null) return;
    error = null;
    if (repeatedVerse != null && repeatsLeft <= 0) repeatsLeft = repeatCount;
    if (player.processingState == ja.ProcessingState.completed) {
      if (repeatedVerse != null) repeatsLeft = repeatCount;
      await player.seek(Duration.zero);
    }
    unawaited(
        player.play().catchError((Object e) => _fail('Ses başlatılamadı.')));
  }

  @override
  Future<void> pause() async {
    if (busy) _operation++;
    await player.pause();
    await _savePosition();
  }

  @override
  Future<void> stop() async {
    _operation++;
    await _savePosition();
    await player.stop();
    _broadcast();
  }

  @override
  Future<void> seek(Duration position) async {
    await player.seek(position);
    await _savePosition();
  }

  @override
  Future<void> skipToNext() async {
    if (chapter != null && chapter! < 114) await openChapter(chapter! + 1);
  }

  @override
  Future<void> skipToPrevious() async {
    if (chapter != null && chapter! > 1) await openChapter(chapter! - 1);
  }

  @override
  Future<void> onTaskRemoved() => stop();
  void _broadcast() {
    playbackState.add(PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          player.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext
        ],
        androidCompactActionIndices: const [
          0,
          1,
          3
        ],
        systemActions: const {
          MediaAction.seek
        },
        processingState: switch (player.processingState) {
          ja.ProcessingState.idle => AudioProcessingState.idle,
          ja.ProcessingState.loading => AudioProcessingState.loading,
          ja.ProcessingState.buffering => AudioProcessingState.buffering,
          ja.ProcessingState.ready => AudioProcessingState.ready,
          ja.ProcessingState.completed => AudioProcessingState.completed,
        },
        playing: player.playing,
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition));
    revision.value++;
  }
}
