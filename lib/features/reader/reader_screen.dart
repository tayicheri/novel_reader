import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/favorites_repository.dart';
import '../../services/novel_extractor.dart';
import '../../services/work_title_suggester.dart';
import '../favorites/add_favorite_dialog.dart';

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
  final _titleSuggester = WorkTitleSuggester();
  final _scrollController = ScrollController();

  bool _isDarkMode = false;
  ReaderFontSize _fontSize = ReaderFontSize.medium;
  String? _favoriteId;
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    _favoriteId = widget.favoriteId;
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    _persistProgress();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_favoriteId == null) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), _persistProgress);
  }

  Future<void> _persistProgress() async {
    final id = _favoriteId;
    if (id == null || !_scrollController.hasClients) return;

    await _favoritesRepository.updateProgress(
      id: id,
      url: widget.chapter.sourceUrl,
      scrollOffset: _scrollController.offset,
    );
  }

  Future<void> _openSource() async {
    final uri = Uri.tryParse(widget.chapter.sourceUrl);
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
      chapterTitle: widget.chapter.title,
      sourceUrl: widget.chapter.sourceUrl,
    );

    if (!mounted) return;

    final title = await showAddFavoriteDialog(
      context: context,
      suggestedTitle: suggestedTitle,
    );

    if (title == null || !mounted) return;

    final favorite = await _favoritesRepository.save(
      title: title,
      lastUrl: widget.chapter.sourceUrl,
      scrollOffset: _scrollController.hasClients ? _scrollController.offset : 0,
    );

    if (!mounted) return;
    setState(() => _favoriteId = favorite.id);
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = _isDarkMode ? AppTheme.dark() : AppTheme.light();
    final bodyStyle = GoogleFonts.inter(
      fontSize: 16 * _fontSize.scale,
      height: 1.7,
      color: baseTheme.textTheme.bodyMedium?.color,
    );

    return Theme(
      data: baseTheme,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            widget.chapter.title,
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
              tooltip: _isDarkMode ? 'Mode clair' : 'Mode sombre',
              onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
              icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
            ),
            IconButton(
              tooltip: 'Ouvrir la source',
              onPressed: _openSource,
              icon: const Icon(Icons.open_in_new),
            ),
          ],
        ),
        body: Column(
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
              child: Scrollbar(
                controller: _scrollController,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.chapter.title,
                        style: baseTheme.textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 20),
                      SelectableText(
                        widget.chapter.content,
                        style: bodyStyle,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
