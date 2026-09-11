import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../data/models/cached_audio.dart';
import '../data/repositories/audio_progress_repository.dart';

class AudioPlaybackService {
  AudioPlaybackService({AudioProgressRepository? progress})
      : _progress = progress ?? AudioProgressRepository.instance;

  final AudioPlayer _player = AudioPlayer();
  final AudioProgressRepository _progress;

  String? _currentUrl;
  String _title = 'Tayi Whisper';
  bool _appendCancelled = false;
  bool _sessionReady = false;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  bool get isPlaying => _player.playing;
  String? get currentUrl => _currentUrl;
  Duration get totalDuration => _player.duration ?? Duration.zero;
  ProcessingState get processingState => _player.processingState;

  Future<void> _ensureAudioSession() async {
    if (_sessionReady) return;
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    _sessionReady = true;
  }

  AudioSource _sourceFor(String path) {
    return AudioSource.file(
      path,
      tag: MediaItem(
        id: _currentUrl ?? path,
        title: _title,
        album: 'Tayi Whisper',
        artist: 'Tayi Whisper',
      ),
    );
  }

  Future<void> play({
    required String sourceUrl,
    required CachedAudio audio,
    String? title,
  }) async {
    await _ensureAudioSession();
    _cancelAppend();
    _currentUrl = sourceUrl;
    _title = title?.trim().isNotEmpty == true ? title!.trim() : 'Tayi Whisper';

    await _player.setAudioSources(
      audio.segmentPaths.map(_sourceFor).toList(),
    );

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
    String? title,
  }) async {
    await _ensureAudioSession();
    _cancelAppend();
    _currentUrl = sourceUrl;
    _title = title?.trim().isNotEmpty == true ? title!.trim() : 'Tayi Whisper';
    _appendCancelled = false;

    await _player.setAudioSources([_sourceFor(firstSegmentPath)]);

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
      await _player.addAudioSource(_sourceFor(path));
      if (!_appendCancelled &&
          !_player.playing &&
          _player.processingState == ProcessingState.completed) {
        await _player.play();
      }
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
