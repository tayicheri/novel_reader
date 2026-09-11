import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../services/audio_playback_service.dart';
import '../../services/chapter_audio_loader_service.dart';
import '../../services/novel_extractor.dart';
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

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _playerStateSub;

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
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _checkCache();
    if (widget.autoPlay && mounted) {
      await _startPlayback();
    }
  }

  void _bindStreams() {
    _positionSub = widget.playback.positionStream.listen((position) {
      if (!mounted || _isDragging) return;
      setState(() => _position = position);
    });
    _durationSub = widget.playback.durationStream.listen((duration) {
      if (!mounted || duration == null) return;
      setState(() => _duration = duration);
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

  Future<void> _onChapterChanged() async {
    await widget.playback.stop();
    _finishedNotified = false;
    _segmentsFullyLoaded = false;
    setState(() {
      _uiState = AudioPlayerUiState.idle;
      _activeSession = null;
      _errorMessage = null;
      _position = Duration.zero;
      _duration = Duration.zero;
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
        setState(() {
          _uiState = AudioPlayerUiState.ready;
          _duration = Duration(milliseconds: cached.durationMs);
        });
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
          await widget.playback.play(
            sourceUrl: widget.chapter.sourceUrl,
            audio: cached,
            title: widget.chapter.title,
          );
          if (!mounted) return;
          setState(() {
            _uiState = AudioPlayerUiState.playing;
            _duration = Duration(milliseconds: cached.durationMs);
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
    _segmentsFullyLoaded = session.isComplete;

    await widget.playback.playProgressive(
      sourceUrl: widget.chapter.sourceUrl,
      firstSegmentPath: firstPath,
      title: widget.chapter.title,
      produceNextSegment: session.synthesizeNext,
      onAllSegmentsLoaded: () async {
        _segmentsFullyLoaded = true;
        if (!mounted || _activeSession == null) return;
        final durationMs = widget.playback.totalDuration.inMilliseconds;
        await widget.audioLoader.savePlaybackSession(
          session,
          durationMs: durationMs > 0 ? durationMs : _estimateDurationMs(),
        );
        if (!mounted) return;
        setState(() => _uiState = AudioPlayerUiState.playing);
      },
    );

    if (!mounted) return;
    setState(() => _uiState = AudioPlayerUiState.playing);
    _prefetchNext();
  }

  void _prefetchNext() {
    widget.audioLoader.onChapterDisplayed(widget.chapter);
  }

  int _estimateDurationMs() {
    return (widget.chapter.content.length / 14 * 1000).round();
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
    await widget.playback.seek(target);
    if (!mounted) return;
    setState(() => _position = target);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  bool get _canPlay =>
      _uiState != AudioPlayerUiState.preparing &&
      _uiState != AudioPlayerUiState.error;

  bool get _canReload => _uiState != AudioPlayerUiState.preparing;

  Widget _reloadButton() {
    return IconButton(
      tooltip: 'Régénérer l\'audio',
      onPressed: _canReload ? _reloadAudio : null,
      icon: const Icon(Icons.refresh),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_uiState == AudioPlayerUiState.idle ||
                              _uiState == AudioPlayerUiState.ready)
                            Text(
                              _uiState == AudioPlayerUiState.ready
                                  ? 'Audio en cache — appuyez pour écouter'
                                  : 'Appuyez pour écouter',
                              style: theme.textTheme.bodySmall,
                            )
                          else ...[
                            Slider(
                              value: _position.inMilliseconds
                                  .clamp(0, maxMs.round())
                                  .toDouble(),
                              max: maxMs,
                              onChangeStart: (_) => _isDragging = true,
                              onChanged: (value) {
                                setState(() {
                                  _position =
                                      Duration(milliseconds: value.round());
                                });
                              },
                              onChangeEnd: _onSeekEnd,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                _formatDuration(_position),
                                style: theme.textTheme.labelSmall,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    _reloadButton(),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
