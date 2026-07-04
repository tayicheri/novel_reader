import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../data/models/cached_audio.dart';
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
  });

  final NovelChapter chapter;
  final AudioPlaybackService playback;
  final ChapterAudioLoaderService audioLoader;

  @override
  State<ChapterAudioPlayerBar> createState() => ChapterAudioPlayerBarState();
}

class ChapterAudioPlayerBarState extends State<ChapterAudioPlayerBar> {
  AudioPlayerUiState _uiState = AudioPlayerUiState.idle;
  CachedAudio? _cachedAudio;
  ProgressiveAudioSession? _activeSession;
  String? _errorMessage;

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
    _checkCache();
  }

  @override
  void didUpdateWidget(covariant ChapterAudioPlayerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapter.sourceUrl != widget.chapter.sourceUrl) {
      _onChapterChanged();
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playerStateSub?.cancel();
    super.dispose();
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
    setState(() {
      _uiState = AudioPlayerUiState.idle;
      _cachedAudio = null;
      _activeSession = null;
      _errorMessage = null;
      _position = Duration.zero;
      _duration = Duration.zero;
    });
    await _checkCache();
  }

  Future<void> _checkCache() async {
    try {
      final cached = await widget.audioLoader.getCachedAudio(widget.chapter);
      if (!mounted) return;
      if (cached != null) {
        setState(() {
          _cachedAudio = cached;
          _uiState = AudioPlayerUiState.ready;
          _duration = Duration(milliseconds: cached.durationMs);
        });
      }
    } catch (_) {
      // reste en idle
    }
  }

  Future<void> _startPlayback() async {
    if (_uiState == AudioPlayerUiState.preparing) return;

    setState(() {
      _uiState = AudioPlayerUiState.preparing;
      _errorMessage = null;
    });

    try {
      final cached = _cachedAudio ?? await widget.audioLoader.getCachedAudio(widget.chapter);
      if (!mounted) return;

      if (cached != null) {
        _cachedAudio = cached;
        try {
          await widget.playback.play(
            sourceUrl: widget.chapter.sourceUrl,
            audio: cached,
          );
          if (!mounted) return;
          setState(() {
            _uiState = AudioPlayerUiState.playing;
            _duration = Duration(milliseconds: cached.durationMs);
          });
          return;
        } on PlayerException {
          await widget.audioLoader.invalidateCachedAudio(widget.chapter);
          _cachedAudio = null;
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
    final session = await widget.audioLoader.createPlaybackSession(widget.chapter);
    final firstPath = await session.synthesizeNext();
    if (!mounted || firstPath == null) return;

    _activeSession = session;

    await widget.playback.playProgressive(
      sourceUrl: widget.chapter.sourceUrl,
      firstSegmentPath: firstPath,
      produceNextSegment: session.synthesizeNext,
      onAllSegmentsLoaded: () async {
        if (!mounted || _activeSession == null) return;
        final durationMs = widget.playback.totalDuration.inMilliseconds;
        final saved = await widget.audioLoader.savePlaybackSession(
          session,
          durationMs: durationMs > 0 ? durationMs : _estimateDurationMs(),
        );
        if (!mounted) return;
        setState(() => _cachedAudio = saved);
      },
    );

    if (!mounted) return;
    setState(() => _uiState = AudioPlayerUiState.playing);
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
      _cachedAudio = null;
      _activeSession = null;
      _errorMessage = null;
      _position = Duration.zero;
      _duration = Duration.zero;
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
