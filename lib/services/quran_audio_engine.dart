import 'package:just_audio/just_audio.dart' as ja;

abstract class QuranAudioEngine {
  Stream<ja.PlayerState> get playerStateStream;
  Stream<Object?> get playbackEventStream;
  Stream<Object> get errorStream;
  Stream<Duration> get positionStream;
  bool get playing;
  ja.ProcessingState get processingState;
  Duration get position;
  Duration get bufferedPosition;
  Duration? get duration;
  Future<void> load(Uri uri, {Duration initialPosition = Duration.zero});
  Future<void> setClip({Duration? start, Duration? end});
  Future<void> seek(Duration position);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> dispose();
}

class JustQuranAudioEngine implements QuranAudioEngine {
  final _player = ja.AudioPlayer();
  @override
  Stream<ja.PlayerState> get playerStateStream => _player.playerStateStream;
  @override
  Stream<Object?> get playbackEventStream => _player.playbackEventStream;
  @override
  Stream<Object> get errorStream => _player.errorStream;
  @override
  Stream<Duration> get positionStream => _player.positionStream;
  @override
  bool get playing => _player.playing;
  @override
  ja.ProcessingState get processingState => _player.processingState;
  @override
  Duration get position => _player.position;
  @override
  Duration get bufferedPosition => _player.bufferedPosition;
  @override
  Duration? get duration => _player.duration;
  @override
  Future<void> load(Uri uri, {Duration initialPosition = Duration.zero}) async {
    await _player.setAudioSource(ja.AudioSource.uri(uri),
        initialPosition: initialPosition);
  }

  @override
  Future<void> setClip({Duration? start, Duration? end}) async {
    await _player.setClip(start: start, end: end);
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> dispose() => _player.dispose();
}
