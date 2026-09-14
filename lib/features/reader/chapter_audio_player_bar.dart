import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../data/repositories/settings_repository.dart';
import '../../services/audio_playback_service.dart';
import '../../services/chapter_audio_loader_service.dart';
import '../../services/novel_extractor.dart';
import '../../services/tts/chapter_audio_progress.dart';
import '../../services/tts/progressive_audio_session.dart';
import '../../services/tts/tts_provider.dart';

enum AudioPlayerUiState { idle, preparing, ready, playing, paused, error }

class ChapterAudioPlayerBar extends StatefulWidget {
  const ChapterAudioPlayerBar({
    super.key,
    required this.chapter,
    required this.playback,
    required this.audioLoader,
    this.autoPlay = false,
    this.onChapterFinished,
  });

  final NovelChapter chapter;
  final AudioPlaybackService playback;
  final ChapterAudioLoaderService audioLoader;
  final bool autoPlay;
  final VoidCallback? onChapterFinished;

  @override
  State<ChapterAudioPlayerBar> createState() => ChapterAudioPlayerBarState();
}

class ChapterAudioPlayerBarState extends State<ChapterAudioPlayerBar> {
  AudioPlayerUiState _uiState = AudioPlayerUiState.idle;
  ProgressiveAudioSession? _activeSession;
  String? _errorMessage;
  bool _segmentsFullyLoaded = false;
  bool _finishedNotified = false;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isDragging = false;
  bool _durationIsEstimate = false;
  double _ttsFraction = 0;
  TtsEngine? _engine;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<SequenceState>? _sequenceSub;

  bool get _useChapterProgress =>
      _engine == TtsEngine.kokoro ||
      _activeSession?.engine == TtsEngine.kokoro;

  @override
  void initState() {
    super.initState();
    _bindStreams();
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant ChapterAudioPlayerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapter.sourceUrl != widget.chapter.sourceUrl) {
      _onChapterChanged();
    } else if (widget.autoPlay &&
        !oldWidget.autoPlay &&
        (_uiState == AudioPlayerUiState.idle ||
            _uiState == AudioPlayerUiState.ready)) {
      unawaited(_startPlayback());
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playerStateSub?.cancel();
    _sequenceSub?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _resolveEngine();
    await _checkCache();
    if (widget.autoPlay && mounted) {
      await _startPlayback();
    }
  }

  Future<void> _resolveEngine() async {
    final engine = await SettingsRepository.instance.resolveEffectiveEngine();
    if (!mounted) return;
    _engine = engine;
    if (_useChapterProgress) {
      _applyChapterProgress();
    }
  }

  void _bindStreams() {
    _positionSub = widget.playback.positionStream.listen((position) {
      if (!mounted || _isDragging) return;
      setState(() {
        _position = _useChapterProgress
            ? widget.playback.playlistPosition
            : position;
      });
    });
    _durationSub = widget.playback.durationStream.listen((duration) {
      if (!mounted || duration == null || _useChapterProgress) return;
      setState(() => _duration = duration);
    });
    _sequenceSub = widget.playback.sequenceStateStream.listen((_) {
      if (!mounted || !_useChapterProgress || _isDragging) return;
      setState(() {
        _position = widget.playback.playlistPosition;
        if (!_durationIsEstimate) {
          final loaded = widget.playback.loadedDuration;
          if (loaded > Duration.zero) {
            _duration = loaded;
          }
        }
      });
    });
    _playerStateSub = widget.playback.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.loading) return;
      if (state.processingState == ProcessingState.completed &&
          _segmentsFullyLoaded &&
          !_finishedNotified &&
          widget.playback.currentUrl == widget.chapter.sourceUrl) {
        _finishedNotified = true;
        widget.onChapterFinished?.call();
        return;
      }
      setState(() {
        if (state.playing) {
          _uiState = AudioPlayerUiState.playing;
        } else if (_uiState == AudioPlayerUiState.playing) {
          _uiState = AudioPlayerUiState.paused;
        }
      });
    });
  }

  void _applyChapterProgress({int? cachedDurationMs}) {
    if (cachedDurationMs != null) {
      _duration = Duration(milliseconds: cachedDurationMs);
      _durationIsEstimate = false;
      _ttsFraction = 1;
      return;
    }
    _duration = ChapterAudioProgress.estimateDuration(widget.chapter.content);
    _durationIsEstimate = true;
    _ttsFraction = _activeSession?.synthesizedTextFraction ?? 0;
  }

  Future<void> _onChapterChanged() async {
    await widget.playback.stop();
    _finishedNotified = false;
    _segmentsFullyLoaded = false;
    _activeSession = null;
    await _resolveEngine();
    if (!mounted) return;
    setState(() {
      _uiState = AudioPlayerUiState.idle;
      _errorMessage = null;
      _position = Duration.zero;
      _duration = Duration.zero;
      _durationIsEstimate = false;
      _ttsFraction = 0;
    });
    await _checkCache();
    if (widget.autoPlay && mounted) {
      await _startPlayback();
    }
  }

  Future<void> _checkCache() async {
    try {
      final cached = await widget.audioLoader.getCachedAudio(widget.chapter);
      if (!mounted) return;
      if (cached != null) {
        _engine = cached.engine;
        setState(() {
          _uiState = AudioPlayerUiState.ready;
          if (_useChapterProgress) {
            _applyChapterProgress(cachedDurationMs: cached.durationMs);
          } else {
            _duration = Duration(milliseconds: cached.durationMs);
            _durationIsEstimate = false;
            _ttsFraction = 0;
          }
        });
      } else if (_useChapterProgress) {
        setState(() => _applyChapterProgress());
      }
    } catch (_) {
      // reste en idle
    }
  }

  Future<void> startPlayback() => _startPlayback();

  Future<void> _startPlayback() async {
    if (_uiState == AudioPlayerUiState.preparing) return;

    setState(() {
      _uiState = AudioPlayerUiState.preparing;
      _errorMessage = null;
      _finishedNotified = false;
    });

    try {
      final cached = await widget.audioLoader.getCachedAudio(widget.chapter);
      if (!mounted) return;

      if (cached != null) {
        try {
          _segmentsFullyLoaded = true;
          _engine = cached.engine;
          await widget.playback.play(
            sourceUrl: widget.chapter.sourceUrl,
            audio: cached,
            title: widget.chapter.title,
          );
          if (!mounted) return;
          setState(() {
            _uiState = AudioPlayerUiState.playing;
            if (_useChapterProgress) {
              _applyChapterProgress(cachedDurationMs: cached.durationMs);
            } else {
              _duration = Duration(milliseconds: cached.durationMs);
            }
          });
          _prefetchNext();
          return;
        } on PlayerException {
          _segmentsFullyLoaded = false;
          await widget.audioLoader.invalidateCachedAudio(widget.chapter);
        }
      }

      await _playProgressive();
    } on TtsSynthesisException catch (error) {
      if (!mounted) return;
      setState(() {
        _uiState = AudioPlayerUiState.error;
        _errorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _uiState = AudioPlayerUiState.error;
        _errorMessage = 'Impossible de démarrer la lecture audio.';
      });
    }
  }

  Future<void> _playProgressive() async {
    final session =
        await widget.audioLoader.createPlaybackSession(widget.chapter);
    final firstPath = await session.firstSegmentPath();
    if (!mounted || firstPath == null) return;

    _activeSession = session;
    _engine = session.engine;
    _segmentsFullyLoaded = session.isComplete;

    await widget.playback.playProgressive(
      sourceUrl: widget.chapter.sourceUrl,
      firstSegmentPath: firstPath,
      title: widget.chapter.title,
      keepCpuAwake: true,
      produceNextSegment: () async {
        final path = await session.synthesizeNext();
        if (mounted && session.engine == TtsEngine.kokoro) {
          setState(() {
            _ttsFraction = session.synthesizedTextFraction;
          });
        }
        return path;
      },
      onAllSegmentsLoaded: () async {
        _segmentsFullyLoaded = true;
        if (!mounted || _activeSession == null) return;
        final realDuration = widget.playback.loadedDuration;
        final durationMs = realDuration.inMilliseconds > 0
            ? realDuration.inMilliseconds
            : ChapterAudioProgress.estimateDuration(widget.chapter.content)
                .inMilliseconds;
        await widget.audioLoader.savePlaybackSession(
          session,
          durationMs: durationMs,
        );
        if (!mounted) return;
        setState(() {
          _uiState = AudioPlayerUiState.playing;
          if (session.engine == TtsEngine.kokoro) {
            _durationIsEstimate = false;
            _duration = Duration(milliseconds: durationMs);
            _ttsFraction = 1;
            _position = widget.playback.playlistPosition;
          }
        });
      },
    );

    if (!mounted) return;
    setState(() {
      _uiState = AudioPlayerUiState.playing;
      if (session.engine == TtsEngine.kokoro) {
        _applyChapterProgress();
        _ttsFraction = session.synthesizedTextFraction;
        _position = widget.playback.playlistPosition;
      }
    });
    _prefetchNext();
  }

  void _prefetchNext() {
    widget.audioLoader.onChapterDisplayed(widget.chapter);
  }

  Future<void> _reloadAudio() async {
    if (_uiState == AudioPlayerUiState.preparing) return;

    await widget.playback.stop();
    await widget.audioLoader.reloadChapterAudio(widget.chapter);

    if (!mounted) return;
    setState(() {
      _activeSession = null;
      _errorMessage = null;
      _position = Duration.zero;
      _duration = Duration.zero;
      _durationIsEstimate = false;
      _ttsFraction = 0;
      _segmentsFullyLoaded = false;
      _finishedNotified = false;
    });

    await _startPlayback();
  }

  Future<void> _togglePlayback() async {
    if (_uiState == AudioPlayerUiState.idle ||
        _uiState == AudioPlayerUiState.ready ||
        _uiState == AudioPlayerUiState.preparing) {
      await _startPlayback();
      return;
    }

    if (_uiState == AudioPlayerUiState.playing) {
      await widget.playback.pause();
      setState(() => _uiState = AudioPlayerUiState.paused);
      return;
    }

    if (_uiState == AudioPlayerUiState.paused) {
      await widget.playback.resume();
      setState(() => _uiState = AudioPlayerUiState.playing);
    }
  }

  Future<void> _onSeekEnd(double value) async {
    _isDragging = false;
    final target = Duration(milliseconds: value.round());
    if (_useChapterProgress) {
      await widget.playback.seekPlaylist(target);
      if (!mounted) return;
      setState(() => _position = widget.playback.playlistPosition);
      return;
    }
    await widget.playback.seek(target);
    if (!mounted) return;
    setState(() => _position = target);
  }

  String _formatDuration(Duration duration, {bool estimate = false}) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final clock = hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
    return estimate ? '~$clock' : clock;
  }

  bool get _canPlay =>
      _uiState != AudioPlayerUiState.preparing &&
      _uiState != AudioPlayerUiState.error;

  bool get _canReload => _uiState != AudioPlayerUiState.preparing;

  bool get _showChapterSlider {
    if (!_useChapterProgress) {
      return _uiState != AudioPlayerUiState.idle &&
          _uiState != AudioPlayerUiState.ready;
    }
    return true;
  }

  Widget _reloadButton() {
    return IconButton(
      tooltip: 'Régénérer l\'audio',
      onPressed: _canReload ? _reloadAudio : null,
      icon: const Icon(Icons.refresh),
    );
  }

  Widget _progressSlider(ThemeData theme, double maxMs) {
    final playbackMs =
        _position.inMilliseconds.clamp(0, maxMs.round()).toDouble();
    final ttsMs = (_ttsFraction * maxMs).clamp(0, maxMs).toDouble();
    final interactive = _uiState == AudioPlayerUiState.playing ||
        _uiState == AudioPlayerUiState.paused;

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        overlayShape: SliderComponentShape.noOverlay,
        secondaryActiveTrackColor:
            theme.colorScheme.primary.withValues(alpha: 0.28),
      ),
      child: IgnorePointer(
        ignoring: !interactive,
        child: Slider(
          value: playbackMs,
          secondaryTrackValue: ttsMs,
          max: maxMs,
          onChangeStart: (_) => _isDragging = true,
          onChanged: (value) {
            setState(() {
              _position = Duration(milliseconds: value.round());
            });
          },
          onChangeEnd: _onSeekEnd,
        ),
      ),
    );
  }

  Widget _progressLabels(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 56),
      child: Row(
        children: [
          Text(
            _formatDuration(_position),
            style: theme.textTheme.labelSmall,
          ),
          const Spacer(),
          if (_useChapterProgress)
            Text(
              '${(_ttsFraction * 100).round()}% TTS',
              style: theme.textTheme.labelSmall,
            ),
          if (_useChapterProgress) const SizedBox(width: 8),
          Text(
            _formatDuration(_duration, estimate: _durationIsEstimate),
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxMs = _duration.inMilliseconds > 0
        ? _duration.inMilliseconds.toDouble()
        : 1.0;

    return Material(
      elevation: 8,
      color: theme.colorScheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_uiState == AudioPlayerUiState.preparing)
                Row(
                  children: [
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Démarrage de la lecture…',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                )
              else if (_uiState == AudioPlayerUiState.error)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _errorMessage ?? 'Erreur audio',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                    _reloadButton(),
                    TextButton(
                      onPressed: _startPlayback,
                      child: const Text('Réessayer'),
                    ),
                  ],
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: _uiState == AudioPlayerUiState.playing
                              ? 'Pause'
                              : 'Lecture',
                          onPressed: _canPlay ? _togglePlayback : null,
                          icon: Icon(
                            _uiState == AudioPlayerUiState.playing
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                            size: 40,
                          ),
                        ),
                        Expanded(
                          child: _showChapterSlider
                              ? _progressSlider(theme, maxMs)
                              : Text(
                                  _uiState == AudioPlayerUiState.ready
                                      ? 'Audio en cache — appuyez pour écouter'
                                      : 'Appuyez pour écouter',
                                  style: theme.textTheme.bodySmall,
                                ),
                        ),
                        _reloadButton(),
                      ],
                    ),
                    if (_showChapterSlider) _progressLabels(theme),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
