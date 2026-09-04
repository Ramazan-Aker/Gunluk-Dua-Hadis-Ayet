import 'dart:async';
import 'package:daily_dua_hadith/services/quran_audio_engine.dart';
import 'package:daily_dua_hadith/services/quran_listening_service.dart';
import 'package:daily_dua_hadith/screens/quran_listening_screen.dart';
import 'package:daily_dua_hadith/models/chapter_recitation.dart';
import 'package:daily_dua_hadith/models/verse_timing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:shared_preferences/shared_preferences.dart';

class FakeEngine implements QuranAudioEngine {
  final states = StreamController<ja.PlayerState>.broadcast();
  @override
  Stream<ja.PlayerState> get playerStateStream => states.stream;
  @override
  Stream<Object?> get playbackEventStream => const Stream.empty();
  @override
  Stream<Object> get errorStream => const Stream.empty();
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  bool playing = false;
  @override
  ja.ProcessingState processingState = ja.ProcessingState.idle;
  @override
  Duration position = Duration.zero;
  @override
  Duration get bufferedPosition => position;
  @override
  Duration? duration = const Duration(seconds: 20);
  int starts = 0;
  Duration? clipStart, clipEnd;
  void emit() => states.add(ja.PlayerState(playing, processingState));
  @override
  Future<void> load(Uri uri, {Duration initialPosition = Duration.zero}) async {
    position = initialPosition;
    processingState = ja.ProcessingState.ready;
    emit();
  }

  @override
  Future<void> setClip({Duration? start, Duration? end}) async {
    clipStart = start;
    clipEnd = end;
    duration = end == null
        ? const Duration(seconds: 20)
        : end - (start ?? Duration.zero);
    processingState = ja.ProcessingState.ready;
  }

  @override
  Future<void> seek(Duration p) async {
    position = p;
    processingState = ja.ProcessingState.ready;
    emit();
  }

  @override
  Future<void> play() async {
    playing = true;
    starts++;
    emit();
  }

  @override
  Future<void> pause() async {
    playing = false;
    emit();
  }

  @override
  Future<void> stop() async {
    playing = false;
    processingState = ja.ProcessingState.idle;
    emit();
  }

  void complete() {
    position = duration!;
    processingState = ja.ProcessingState.completed;
    emit();
  }

  @override
  Future<void> dispose() async {
    await states.close();
  }
}

ChapterRecitationResult rec(int n) => ChapterRecitationResult(
        audioUrl: 'https://example.org/$n.mp3',
        quranComReciterId: 5,
        timings: [
          VerseTiming(
              verseKey: '$n:1',
              timestampFrom: 0,
              timestampTo: 10000,
              segments: []),
          VerseTiming(
              verseKey: '$n:2',
              timestampFrom: 10000,
              timestampTo: 20000,
              segments: [])
        ]);
Future<void> flush() async {
  for (var i = 0; i < 15; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('Repeat counts stop exactly after 3, 5 or 10 plays', () async {
    for (final count in [3, 5, 10]) {
      final engine = FakeEngine();
      final h = QuranListeningHandler(
          player: engine, loadRecitation: (n) async => rec(n));
      await h.openChapter(1, autoplay: false);
      await h.repeatVerse(2, count);
      await flush();
      expect(engine.clipStart, const Duration(seconds: 10));
      expect(engine.clipEnd, const Duration(seconds: 20));
      for (var i = 0; i < count; i++) {
        engine.complete();
        await flush();
      }
      expect(engine.starts, count);
      expect(engine.playing, isFalse);
      expect(h.chapter, 1);
      expect(h.repeatsLeft, 0);
      await engine.dispose();
    }
  });
  test('Automatic continuation and final surah stopping', () async {
    final e = FakeEngine();
    final h =
        QuranListeningHandler(player: e, loadRecitation: (n) async => rec(n));
    await h.openChapter(113);
    await flush();
    e.complete();
    await flush();
    expect(h.chapter, 114);
    expect(e.playing, isTrue);
    e.complete();
    await flush();
    expect(h.chapter, 114);
    expect(e.playing, isFalse);
    await e.dispose();
  });
  test('Bookmark uses absolute chapter position during verse repeat', () async {
    final e = FakeEngine();
    final h =
        QuranListeningHandler(player: e, loadRecitation: (n) async => rec(n));
    await h.openChapter(2, autoplay: false);
    await h.repeatVerse(2, 3);
    e.position = const Duration(seconds: 3);
    await h.pause();
    final saved = ListeningBookmark.parse(
        (await SharedPreferences.getInstance())
            .getString('quran_listen_bookmark'))!;
    expect(saved.chapter, 2);
    expect(saved.positionMs, 13000);
    await h.openChapter(saved.chapter,
        start: Duration(milliseconds: saved.positionMs), autoplay: false);
    expect(e.position, const Duration(seconds: 13));
    expect(e.playing, isFalse);
    await e.dispose();
  });
  test('Remote stop cancels an in-flight load and prevents late playback',
      () async {
    final e = FakeEngine();
    final loading = Completer<ChapterRecitationResult?>();
    final h =
        QuranListeningHandler(player: e, loadRecitation: (_) => loading.future);
    final work = h.openChapter(1);
    await flush();
    await h.stop();
    loading.complete(rec(1));
    await work;
    await flush();
    expect(e.starts, 0);
    expect(e.playing, isFalse);
    await e.dispose();
  });
  test('Network failure stops playback and exposes a recoverable error',
      () async {
    final e = FakeEngine();
    final h =
        QuranListeningHandler(player: e, loadRecitation: (_) async => null);
    await h.openChapter(1);
    expect(h.error, isNotNull);
    expect(e.playing, isFalse);
    expect(h.busy, isFalse);
    await e.dispose();
  });
  testWidgets(
      'Listening controls fit narrow screens and contain no download action',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final e = FakeEngine();
    final h =
        QuranListeningHandler(player: e, loadRecitation: (n) async => rec(n));
    await h.openChapter(1, autoplay: false);
    await tester
        .pumpWidget(MaterialApp(builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)), child: child!), home: QuranListeningScreen(handler: h)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('10 kez'), 200);
    await tester.pumpAndSettle();
    expect(find.text('10 kez'), findsOneWidget);
    expect(find.byIcon(Icons.download), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await e.dispose();
  });
}
