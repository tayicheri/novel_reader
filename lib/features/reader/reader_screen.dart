import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/favorites_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../services/audio_playback_service.dart';
import '../../services/chapter_audio_loader_service.dart';
import '../../services/chapter_loader_service.dart';
import '../../services/novel_extractor.dart';
import '../../services/work_title_suggester.dart';
import '../favorites/add_favorite_dialog.dart';
import 'chapter_audio_player_bar.dart';
import 'chapter_swipe_hints.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.chapter,
    this.favoriteId,
    this.initialScrollOffset = 0,
  });

  final NovelChapter chapter;
  final String? favoriteId;
  final double initialScrollOffset;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _favoritesRepository = FavoritesRepository.instance;
  final _settingsRepository = SettingsRepository.instance;
  final _titleSuggester = WorkTitleSuggester();
  final _chapterLoader = ChapterLoaderService.instance;
  final _audioLoader = ChapterAudioLoaderService.instance;
  final _audioPlayback = AudioPlaybackService();
  final _scrollController = ScrollController();

  static const _swipeDistanceThreshold = 80.0;
  static const _idleDuration = Duration(milliseconds: 1500);

  late NovelChapter _currentChapter;

  ReaderFontSize _fontSize = ReaderFontSize.medium;
  String? _favoriteId;
  bool _isNavigating = false;
  bool _showHints = false;

  Timer? _saveDebounce;
  Timer? _idleTimer;
  Offset? _pointerDown;

  @override
  void initState() {
    super.initState();
    _currentChapter = widget.chapter;
    _favoriteId = widget.favoriteId;
    _scrollController.addListener(_onScroll);
    _scheduleIdleHints();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chapterLoader.onChapterDisplayed(_currentChapter);
      _audioLoader.onChapterDisplayed(_currentChapter);
      if (!mounted || widget.initialScrollOffset <= 0) return;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          widget.initialScrollOffset.clamp(
            0,
            _scrollController.position.maxScrollExtent,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _idleTimer?.cancel();
    _persistProgress();
    _audioPlayback.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    _onUserInteraction();
    if (_favoriteId == null) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), _persistProgress);
  }

  void _onUserInteraction() {
    if (_showHints) {
      setState(() => _showHints = false);
    }
    _scheduleIdleHints();
  }

  void _scheduleIdleHints() {
    _idleTimer?.cancel();
    if (_currentChapter.previousUrl == null && _currentChapter.nextUrl == null) {
      return;
    }
    _idleTimer = Timer(_idleDuration, () {
      if (!mounted) return;
      setState(() => _showHints = true);
    });
  }

  Future<void> _persistProgress() async {
    final id = _favoriteId;
    if (id == null || !_scrollController.hasClients) return;

    await _favoritesRepository.updateProgress(
      id: id,
      url: _currentChapter.sourceUrl,
      scrollOffset: _scrollController.offset,
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerDown = event.position;
    _onUserInteraction();
  }

  void _onPointerMove(PointerMoveEvent event) {
    _onUserInteraction();
  }

  void _onPointerUp(PointerUpEvent event) {
    final start = _pointerDown;
    _pointerDown = null;
    if (start == null || _isNavigating) return;

    final delta = event.position - start;
    if (delta.dx.abs() <= delta.dy.abs()) return;

    if (delta.dx < -_swipeDistanceThreshold) {
      _goToNextChapter();
    } else if (delta.dx > _swipeDistanceThreshold) {
      _goToPreviousChapter();
    }
  }

  void _goToNextChapter() {
    final url = _currentChapter.nextUrl;
    if (url == null) {
      _showNavigationMessage('Pas de chapitre suivant');
      return;
    }
    _navigateTo(url);
  }

  void _goToPreviousChapter() {
    final url = _currentChapter.previousUrl;
    if (url == null) {
      _showNavigationMessage('Pas de chapitre précédent');
      return;
    }
    _navigateTo(url);
  }

  void _showNavigationMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _navigateTo(String url) async {
    await _persistProgress();
    await _audioPlayback.stop();
    if (!mounted) return;

    setState(() {
      _isNavigating = true;
      _showHints = false;
    });

    try {
      final chapter = await _chapterLoader.loadChapter(url);
      if (!mounted) return;

      setState(() => _currentChapter = chapter);

      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }

      if (_favoriteId != null) {
        await _favoritesRepository.updateProgress(
          id: _favoriteId!,
          url: url,
          scrollOffset: 0,
        );
      }

      _scheduleIdleHints();
    } on NovelExtractionException catch (error) {
      if (mounted) _showNavigationMessage(error.message);
    } catch (_) {
      if (mounted) {
        _showNavigationMessage('Erreur réseau. Vérifiez votre connexion.');
      }
    } finally {
      if (mounted) {
        setState(() => _isNavigating = false);
      }
    }
  }

  Future<void> _openSource() async {
    final uri = Uri.tryParse(_currentChapter.sourceUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _onFavoritePressed() async {
    if (_favoriteId != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Retirer des favoris'),
          content: const Text(
            'Voulez-vous retirer cette œuvre de vos favoris ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Retirer'),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        await _favoritesRepository.delete(_favoriteId!);
        setState(() => _favoriteId = null);
      }
      return;
    }

    final suggestedTitle = _titleSuggester.suggest(
      chapterTitle: _currentChapter.title,
      sourceUrl: _currentChapter.sourceUrl,
    );

    if (!mounted) return;

    final title = await showAddFavoriteDialog(
      context: context,
      suggestedTitle: suggestedTitle,
    );

    if (title == null || !mounted) return;

    final favorite = await _favoritesRepository.save(
      title: title,
      lastUrl: _currentChapter.sourceUrl,
      scrollOffset: _scrollController.hasClients ? _scrollController.offset : 0,
    );

    if (!mounted) return;
    setState(() => _favoriteId = favorite.id);
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final isDarkMode = baseTheme.brightness == Brightness.dark;
    final bodyStyle = GoogleFonts.inter(
      fontSize: 16 * _fontSize.scale,
      height: 1.7,
      color: baseTheme.textTheme.bodyMedium?.color,
    );
    final hintColor = baseTheme.colorScheme.primary;

    return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            _currentChapter.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              tooltip: _favoriteId != null
                  ? 'Retirer des favoris'
                  : 'Ajouter aux favoris',
              onPressed: _onFavoritePressed,
              icon: Icon(
                _favoriteId != null ? Icons.star : Icons.star_border,
              ),
            ),
            IconButton(
              tooltip: isDarkMode ? 'Mode clair' : 'Mode sombre',
              onPressed: () =>
                  _settingsRepository.setDarkMode(!isDarkMode),
              icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            ),
            IconButton(
              tooltip: 'Ouvrir la source',
              onPressed: _openSource,
              icon: const Icon(Icons.open_in_new),
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Row(
                    children: [
                      Text(
                        'Taille',
                        style: baseTheme.textTheme.labelLarge,
                      ),
                      const SizedBox(width: 12),
                      SegmentedButton<ReaderFontSize>(
                        segments: ReaderFontSize.values
                            .map(
                              (size) => ButtonSegment(
                                value: size,
                                label: Text(size.label),
                              ),
                            )
                            .toList(),
                        selected: {_fontSize},
                        onSelectionChanged: (selection) {
                          setState(() => _fontSize = selection.first);
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Listener(
                    onPointerDown: _onPointerDown,
                    onPointerMove: _onPointerMove,
                    onPointerUp: _onPointerUp,
                    child: Stack(
                      children: [
                        Scrollbar(
                          controller: _scrollController,
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentChapter.title,
                                  style: baseTheme.textTheme.headlineLarge,
                                ),
                                const SizedBox(height: 20),
                                SelectableText(
                                  _currentChapter.content,
                                  style: bodyStyle,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_showHints)
                          ChapterSwipeHints(
                            showPrevious: _currentChapter.previousUrl != null,
                            showNext: _currentChapter.nextUrl != null,
                            color: hintColor,
                          ),
                      ],
                    ),
                  ),
                ),
                ChapterAudioPlayerBar(
                  key: ValueKey(_currentChapter.sourceUrl),
                  chapter: _currentChapter,
                  playback: _audioPlayback,
                  audioLoader: _audioLoader,
                ),
              ],
            ),
            if (_isNavigating)
              const ColoredBox(
                color: Color(0x66000000),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      );
  }
}
