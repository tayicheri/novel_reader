import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants.dart';
import '../../data/models/favorite_work.dart';
import '../../data/repositories/favorites_repository.dart';
import '../../services/chapter_loader_service.dart';
import '../../services/novel_extractor.dart';
import '../favorites/favorite_card.dart';
import '../reader/reader_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _urlController = TextEditingController();
  final _chapterLoader = ChapterLoaderService.instance;
  final _favoritesRepository = FavoritesRepository.instance;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadChapter({String? url}) async {
    final targetUrl = url ?? _urlController.text;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final chapter = await _chapterLoader.loadChapter(targetUrl);
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ReaderScreen(chapter: chapter),
        ),
      );
    } on NovelExtractionException catch (error) {
      setState(() => _errorMessage = error.message);
    } catch (_) {
      setState(() {
        _errorMessage = 'Erreur réseau. Vérifiez votre connexion.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openFavorite(FavoriteWork favorite) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final chapter = await _chapterLoader.loadChapter(favorite.lastUrl);
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ReaderScreen(
            chapter: chapter,
            favoriteId: favorite.id,
            initialScrollOffset: favorite.scrollOffset,
          ),
        ),
      );
    } on NovelExtractionException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur réseau. Vérifiez votre connexion.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.language, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(AppConstants.appName),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Lisez vos novels depuis le web',
                style: theme.textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Collez l’URL d’un chapitre pour extraire le texte et lire confortablement.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lire depuis le web',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _urlController,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.go,
                        onSubmitted: (_) => _isLoading ? null : _loadChapter(),
                        decoration: const InputDecoration(
                          hintText: 'https://exemple.com/chapitre-1',
                          prefixIcon: Icon(Icons.link),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isLoading ? null : () => _loadChapter(),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Charger'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: theme.colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              Text(
                'Mes favoris',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<Box<FavoriteWork>>(
                valueListenable: _favoritesRepository.watchFavorites(),
                builder: (context, box, _) {
                  final favorites = _favoritesRepository.getAll();

                  if (favorites.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Text(
                        'Aucun favori — ajoutez une œuvre depuis le lecteur.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: favorites.length,
                    itemBuilder: (context, index) {
                      final favorite = favorites[index];
                      return FavoriteCard(
                        favorite: favorite,
                        onTap: _isLoading
                            ? () {}
                            : () => _openFavorite(favorite),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
