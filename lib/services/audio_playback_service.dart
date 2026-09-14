import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../data/models/cached_audio.dart';
import '../data/repositories/audio_progress_repository.dart';
import 'cpu_wake_lock.dart';
import 'tts/chapter_audio_progress.dart';

class AudioPlaybackService {
  AudioPlaybackService({
    AudioProgressRepository? progress,
    CpuWakeLock? cpuWakeLock,
  })  : _progress = progress ?? AudioProgressRepository.instance,
        _cpuWakeLock = cpuWakeLock ?? CpuWakeLock();

  final AudioPlayer _player = AudioPlayer();
  final AudioProgressRepository _progress;
  final CpuWakeLock _cpuWakeLock;

  String? _currentUrl;
  String _title = 'Tayi Whisper';
  bool _appendCancelled = false;
  bool _sessionReady = false;
  bool _wakeLockHeld = false;
  int _appendGeneration = 0;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<SequenceState> get sequenceStateStream => _player.sequenceStateStream;

  bool get isPlaying => _player.playing;
  String? get currentUrl => _currentUrl;
  Duration get totalDuration => _player.duration ?? Duration.zero;
  ProcessingState get processingState => _player.processingState;
  int get currentIndex => _player.currentIndex ?? 0;

  List<Duration> get sequenceDurations {
    return _player.sequence
        .map((source) => source.duration ?? Duration.zero)
        .toList();
  }

  Duration get playlistPosition {
    return ChapterAudioProgress.playlistPosition(
      currentIndex: currentIndex,
      itemDurations: sequenceDurations,
      itemPosition: _player.position,
    );
  }

  Duration get loadedDuration {
    return ChapterAudioProgress.loadedDuration(sequenceDurations);
  }

  Future<void> _ensureAudioSession() async {
    if (_sessionReady) return;
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    _sessionReady = true;
  }

  Future<void> _acquireWakeLock() async {
    if (_wakeLockHeld) return;
    _wakeLockHeld = true;
    await _cpuWakeLock.enable();
  }

  Future<void> _releaseWakeLock() async {
    if (!_wakeLockHeld) return;
    _wakeLockHeld = false;
    await _cpuWakeLock.disable();
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
    await _releaseWakeLock();
    _currentUrl = sourceUrl;
    _title = title?.trim().isNotEmpty == true ? title!.trim() : 'Tayi Whisper';

    await _player.setAudioSources(
      audio.segmentPaths.map(_sourceFor).toList(),
    );

    final savedMs = _progress.getPosition(sourceUrl);
    if (savedMs > 0) {
      await seekPlaylist(Duration(milliseconds: savedMs));
    }

    await _player.play();
  }

  /// Démarre la lecture dès le premier segment, puis ajoute les suivants.
  ///
  /// [keepCpuAwake] reste actif jusqu'à la fin de la synthèse restante, pour
  /// que l'app ne soit pas gelée entre deux segments en veille / background.
  Future<void> playProgressive({
    required String sourceUrl,
    required String firstSegmentPath,
    required Future<String?> Function() produceNextSegment,
    Future<void> Function()? onAllSegmentsLoaded,
    String? title,
    bool keepCpuAwake = true,
  }) async {
    await _ensureAudioSession();
    _cancelAppend();
    final generation = ++_appendGeneration;
    _currentUrl = sourceUrl;
    _title = title?.trim().isNotEmpty == true ? title!.trim() : 'Tayi Whisper';
    _appendCancelled = false;

    if (keepCpuAwake) {
      await _acquireWakeLock();
    } else {
      await _releaseWakeLock();
    }

    await _player.setAudioSources([_sourceFor(firstSegmentPath)]);

    final savedMs = _progress.getPosition(sourceUrl);
    if (savedMs > 0) {
      await seekPlaylist(Duration(milliseconds: savedMs));
    }

    unawaited(
      _appendRemainingSegments(
        produceNextSegment,
        onAllSegmentsLoaded,
        generation,
      ),
    );
    await _player.play();
  }

  Future<void> _appendRemainingSegments(
    Future<String?> Function() produceNextSegment,
    Future<void> Function()? onAllSegmentsLoaded,
    int generation,
  ) async {
    try {
      while (!_appendCancelled && generation == _appendGeneration) {
        final path = await produceNextSegment();
        if (generation != _appendGeneration) return;
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
    } finally {
      if (generation == _appendGeneration) {
        await _releaseWakeLock();
      }
    }
  }

  void _cancelAppend() {
    _appendCancelled = true;
  }

  Future<void> pause() async {
    final url = _currentUrl;
    if (url != null) {
      await _progress.savePosition(url, playlistPosition.inMilliseconds);
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
      await _progress.savePosition(url, playlistPosition.inMilliseconds);
    }
  }

  Future<void> seekPlaylist(Duration position) async {
    final durations = sequenceDurations;
    final loaded = ChapterAudioProgress.loadedDuration(durations);
    if (loaded <= Duration.zero) {
      await _player.seek(position);
      final url = _currentUrl;
      if (url != null) {
        await _progress.savePosition(url, position.inMilliseconds);
      }
      return;
    }
    final clamped = position > loaded
        ? loaded
        : (position < Duration.zero ? Duration.zero : position);
    final mapped = ChapterAudioProgress.mapPlaylistSeek(
      requested: clamped,
      itemDurations: durations,
    );
    await _player.seek(mapped.position, index: mapped.index);
    final url = _currentUrl;
    if (url != null) {
      await _progress.savePosition(url, clamped.inMilliseconds);
    }
  }

  Future<void> stop() async {
    _cancelAppend();
    await _releaseWakeLock();
    final url = _currentUrl;
    if (url != null && (_player.playing || playlistPosition > Duration.zero)) {
      await _progress.savePosition(url, playlistPosition.inMilliseconds);
    }
    await _player.stop();
    _currentUrl = null;
  }

  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}
