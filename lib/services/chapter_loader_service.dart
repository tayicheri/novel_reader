import 'dart:async';

import '../data/repositories/pages_cache_repository.dart';
import 'novel_extractor.dart';

class ChapterLoaderService {
  ChapterLoaderService({NovelExtractorService? extractor, PagesCacheRepository? cache}) : _extractor = extractor ?? NovelExtractorService(), _cache = cache ?? PagesCacheRepository.instance;

  static const int prefetchAheadCount = 10;
  static const int keepBehindCount = 5;

  static final ChapterLoaderService instance = ChapterLoaderService();

  final NovelExtractorService _extractor;
  final PagesCacheRepository _cache;
  final Map<String, Future<NovelChapter>> _inFlight = {};

  Future<NovelChapter> loadChapter(String rawUrl) async {
    final chapter = await _resolveChapter(rawUrl);
    onChapterDisplayed(chapter);
    return chapter;
  }

  void onChapterDisplayed(NovelChapter chapter) {
    unawaited(prefetchNext(chapter));
    unawaited(evictBehind(chapter));
  }

  Future<void> prefetchNext(NovelChapter current) async {
    var url = current.nextUrl;
    var linksVisited = 0;

    while (url != null && linksVisited < prefetchAheadCount) {
      linksVisited++;

      try {
        if (_cache.contains(url)) {
          final cached = _cache.get(url);
          url = cached?.nextUrl;
          continue;
        }

        final chapter = await _resolveChapter(url);
        url = chapter.nextUrl;
      } catch (_) {
        break;
      }
    }
  }

  Future<void> evictBehind(NovelChapter current) async {
    var url = current.previousUrl;
    var depth = 1;

    while (url != null) {
      if (!_cache.contains(url)) break;

      final cached = _cache.get(url)!;
      if (depth > keepBehindCount) {
        await _cache.delete(url);
      }
      url = cached.previousUrl;
      depth++;
    }
  }

  Future<NovelChapter> _resolveChapter(String rawUrl) async {
    final key = _cache.normalizeUrl(rawUrl);
    final cached = _cache.get(rawUrl);
    if (cached != null) return cached;

    final existing = _inFlight[key];

    if (existing != null) return existing;

    final future = _fetchFromNetwork(rawUrl);
    _inFlight[key] = future;

    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<NovelChapter> _fetchFromNetwork(String rawUrl) async {
    final chapter = await _extractor.extract(rawUrl);
    await _cache.put(chapter);
    return chapter;
  }
}
