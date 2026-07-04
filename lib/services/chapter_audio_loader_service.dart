import 'dart:async';

import '../core/cache_policy.dart';
import '../data/models/cached_audio.dart';
import '../data/repositories/audio_cache_repository.dart';
import '../data/repositories/audio_progress_repository.dart';
import '../data/repositories/pages_cache_repository.dart';
import '../data/repositories/settings_repository.dart';
import 'chapter_loader_service.dart';
import 'novel_extractor.dart';
import 'tts/progressive_audio_session.dart';
import 'tts/tts_synthesis_service.dart';

class ChapterAudioLoaderService {
  ChapterAudioLoaderService({
    ChapterAudioSynthesis? synthesis,
    AudioCacheRepository? audioCache,
    PagesCacheRepository? pagesCache,
    ChapterLoaderService? chapterLoader,
  })  : _synthesis = synthesis ?? TtsSynthesisService(),
        _audioCache = audioCache ?? AudioCacheRepository.instance,
        _pagesCache = pagesCache ?? PagesCacheRepository.instance,
        _chapterLoader = chapterLoader ?? ChapterLoaderService.instance;

  static final ChapterAudioLoaderService instance = ChapterAudioLoaderService();

  final ChapterAudioSynthesis _synthesis;
  final AudioCacheRepository _audioCache;
  final PagesCacheRepository _pagesCache;
  final ChapterLoaderService _chapterLoader;

  /// Retourne l'audio en cache s'il existe, sinon `null`.
  Future<CachedAudio?> getCachedAudio(NovelChapter chapter) {
    return _synthesis.getCached(chapter.sourceUrl);
  }

  /// Crée une session de synthèse progressive (un segment à la fois).
  Future<ProgressiveAudioSession> createPlaybackSession(NovelChapter chapter) {
    return _synthesis.createSession(
      sourceUrl: chapter.sourceUrl,
      text: chapter.content,
    );
  }

  Future<CachedAudio> savePlaybackSession(
    ProgressiveAudioSession session, {
    required int durationMs,
  }) {
    return _synthesis.saveSession(session, durationMs: durationMs);
  }

  /// Supprime l'audio en cache (fichiers invalides ou format obsolète).
  Future<void> invalidateCachedAudio(NovelChapter chapter) {
    return _audioCache.delete(chapter.sourceUrl);
  }

  /// Efface le cache, la position de lecture et relance une synthèse propre.
  Future<void> reloadChapterAudio(NovelChapter chapter) async {
    await _synthesis.invalidateForReload(chapter.sourceUrl);
    await AudioProgressRepository.instance.delete(chapter.sourceUrl);
  }

  void onChapterDisplayed(NovelChapter chapter) {
    unawaited(_prefetchNextChapterText(chapter));
    unawaited(evictBehindAudio(chapter));
  }

  /// Précharge uniquement le texte du chapitre suivant (pas l'audio).
  Future<void> _prefetchNextChapterText(NovelChapter current) async {
    final url = current.nextUrl;
    if (url == null) return;
    if (_pagesCache.get(url) != null) return;

    try {
      await _resolveChapterText(url);
    } catch (_) {
      // ignore
    }
  }

  Future<void> evictBehindAudio(NovelChapter current) async {
    var url = current.previousUrl;
    var depth = 1;

    while (url != null) {
      final hasNative = _audioCache.contains(url, TtsEngine.native);
      final hasCloudGemini = _audioCache.contains(
        url,
        TtsEngine.cloud,
        cloudProvider: CloudTtsProvider.gemini,
      );
      final hasCloudOpenAi = _audioCache.contains(
        url,
        TtsEngine.cloud,
        cloudProvider: CloudTtsProvider.openai,
      );
      if (!hasNative && !hasCloudGemini && !hasCloudOpenAi) {
        break;
      }

      if (depth > CachePolicy.keepBehindCount) {
        await _audioCache.delete(url);
      }

      final chapter = _pagesCache.get(url);
      url = chapter?.previousUrl;
      depth++;
    }
  }

  Future<NovelChapter> _resolveChapterText(String url) async {
    final cached = _pagesCache.get(url);
    if (cached != null) return cached;
    return _chapterLoader.resolveChapter(url);
  }
}
