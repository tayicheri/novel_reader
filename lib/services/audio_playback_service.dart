import 'dart:async';

import 'package:just_audio/just_audio.dart';
import '../data/models/cached_audio.dart';
import '../data/repositories/audio_progress_repository.dart';

class AudioPlaybackService {
  AudioPlaybackService({AudioProgressRepository? progress})
      : _progress = progress ?? AudioProgressRepository.instance;

  final AudioPlayer _player = AudioPlayer();
  final AudioProgressRepository _progress;

  String? _currentUrl;
  bool _appendCancelled = false;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  bool get isPlaying => _player.playing;
  String? get currentUrl => _currentUrl;
  Duration get totalDuration => _player.duration ?? Duration.zero;

  Future<void> play({
    required String sourceUrl,
    required CachedAudio audio,
  }) async {
    _cancelAppend();
    _currentUrl = sourceUrl;

    if (audio.segmentPaths.length == 1) {
      await _player.setFilePath(audio.segmentPaths.first);
    } else {
      await _player.setAudioSources(
        audio.segmentPaths.map(AudioSource.file).toList(),
      );
    }

    final savedMs = _progress.getPosition(sourceUrl);
    if (savedMs > 0) {
      await _player.seek(Duration(milliseconds: savedMs));
    }

    await _player.play();
  }

  /// Démarre la lecture dès le premier segment, puis ajoute les suivants.
  Future<void> playProgressive({
    required String sourceUrl,
    required String firstSegmentPath,
    required Future<String?> Function() produceNextSegment,
    Future<void> Function()? onAllSegmentsLoaded,
  }) async {
    _cancelAppend();
    _currentUrl = sourceUrl;
    _appendCancelled = false;

    await _player.setAudioSources([AudioSource.file(firstSegmentPath)]);

    final savedMs = _progress.getPosition(sourceUrl);
    if (savedMs > 0) {
      await _player.seek(Duration(milliseconds: savedMs));
    }

    unawaited(_appendRemainingSegments(produceNextSegment, onAllSegmentsLoaded));
    await _player.play();
  }

  Future<void> _appendRemainingSegments(
    Future<String?> Function() produceNextSegment,
    Future<void> Function()? onAllSegmentsLoaded,
  ) async {
    while (!_appendCancelled) {
      final path = await produceNextSegment();
      if (path == null) {
        if (!_appendCancelled) {
          await onAllSegmentsLoaded?.call();
        }
        break;
      }
      if (_appendCancelled) break;
      await _player.addAudioSource(AudioSource.file(path));
    }
  }

  void _cancelAppend() {
    _appendCancelled = true;
  }

  Future<void> pause() async {
    final url = _currentUrl;
    if (url != null) {
      await _progress.savePosition(url, _player.position.inMilliseconds);
    }
    await _player.pause();
  }

  Future<void> resume() async {
    await _player.play();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
    final url = _currentUrl;
    if (url != null) {
      await _progress.savePosition(url, position.inMilliseconds);
    }
  }

  Future<void> stop() async {
    _cancelAppend();
    final url = _currentUrl;
    if (url != null && (_player.playing || _player.position > Duration.zero)) {
      await _progress.savePosition(url, _player.position.inMilliseconds);
    }
    await _player.stop();
    _currentUrl = null;
  }

  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}
