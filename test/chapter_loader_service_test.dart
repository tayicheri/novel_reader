import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:tayi_whisper/data/models/cached_chapter.dart';
import 'package:tayi_whisper/data/repositories/pages_cache_repository.dart';
import 'package:tayi_whisper/services/chapter_loader_service.dart';
import 'package:tayi_whisper/services/novel_extractor.dart';

class _FakeExtractor extends NovelExtractorService {
  _FakeExtractor(this._chapters);

  final Map<String, NovelChapter> _chapters;
  int callCount = 0;

  @override
  Future<NovelChapter> extract(String rawUrl) async {
    callCount++;
    final key = normalizeNovelUrl(rawUrl).toString();
    final chapter = _chapters[key];
    if (chapter == null) {
      throw NovelExtractionException('Chapitre introuvable.');
    }
    return chapter;
  }
}

NovelChapter _chapter({
  required String url,
  String? previousUrl,
  String? nextUrl,
}) {
  return NovelChapter(
    title: 'Titre $url',
    content:
        'Contenu de $url avec suffisamment de texte pour être considéré valide.',
    sourceUrl: url,
    previousUrl: previousUrl,
    nextUrl: nextUrl,
  );
}

void main() {
  group('ChapterLoaderService', () {
    late Box<CachedChapter> box;
    late PagesCacheRepository cache;
    late _FakeExtractor extractor;
    late ChapterLoaderService loader;

    const base = 'https://exemple.com';

    setUp(() async {
      Hive.init('./.dart_tool/test_chapter_loader_hive');
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(CachedChapterAdapter());
      }
      box = await Hive.openBox<CachedChapter>('chapter_loader_test');
      await box.clear();
      cache = PagesCacheRepository.test();
      cache.init(box: box);

      extractor = _FakeExtractor({
        '$base/ch-1': _chapter(
          url: '$base/ch-1',
          nextUrl: '$base/ch-2',
        ),
        '$base/ch-2': _chapter(
          url: '$base/ch-2',
          previousUrl: '$base/ch-1',
          nextUrl: '$base/ch-3',
        ),
        '$base/ch-3': _chapter(
          url: '$base/ch-3',
          previousUrl: '$base/ch-2',
          nextUrl: '$base/ch-4',
        ),
        '$base/ch-4': _chapter(
          url: '$base/ch-4',
          previousUrl: '$base/ch-3',
          nextUrl: '$base/ch-5',
        ),
        for (var i = 5; i <= 15; i++)
          '$base/ch-$i': _chapter(
            url: '$base/ch-$i',
            previousUrl: '$base/ch-${i - 1}',
            nextUrl: i < 15 ? '$base/ch-${i + 1}' : null,
          ),
      });

      loader = ChapterLoaderService(
        extractor: extractor,
        cache: cache,
      );
    });

    tearDown(() async {
      await box.clear();
      await box.close();
    });

    test('loadChapter utilise le cache sans requête réseau', () async {
      final chapter = _chapter(url: '$base/cached');
      await cache.put(chapter);

      final loaded = await loader.loadChapter('$base/cached');

      expect(loaded.sourceUrl, '$base/cached');
      expect(extractor.callCount, 0);
    });

    test('prefetchNext parcourt 10 liens et saute le cache existant', () async {
      await cache.put(_chapter(url: '$base/ch-1', nextUrl: '$base/ch-2'));
      await cache.put(_chapter(url: '$base/ch-2', nextUrl: '$base/ch-3'));

      await loader.prefetchNext(
        _chapter(url: '$base/ch-1', nextUrl: '$base/ch-2'),
      );

      expect(cache.contains('$base/ch-1'), isTrue);
      expect(cache.contains('$base/ch-2'), isTrue);
      expect(cache.contains('$base/ch-3'), isTrue);
      expect(cache.contains('$base/ch-11'), isTrue);
      expect(cache.contains('$base/ch-12'), isFalse);
      expect(extractor.callCount, 9);
    });

    test('evictBehind conserve 5 chapitres et supprime au-delà', () async {
      for (var i = 1; i <= 8; i++) {
        await cache.put(
          _chapter(
            url: '$base/back-$i',
            previousUrl: i > 1 ? '$base/back-${i - 1}' : null,
            nextUrl: i < 8 ? '$base/back-${i + 1}' : null,
          ),
        );
      }

      await loader.evictBehind(
        _chapter(
          url: '$base/current',
          previousUrl: '$base/back-8',
        ),
      );

      expect(cache.contains('$base/back-8'), isTrue);
      expect(cache.contains('$base/back-7'), isTrue);
      expect(cache.contains('$base/back-4'), isTrue);
      expect(cache.contains('$base/back-3'), isFalse);
      expect(cache.contains('$base/back-2'), isFalse);
      expect(cache.contains('$base/back-1'), isFalse);
    });

    test('evictBehind ne fait rien si rien derrière en cache', () async {
      await cache.put(_chapter(url: '$base/only'));

      await loader.evictBehind(
        _chapter(
          url: '$base/current',
          previousUrl: '$base/missing',
        ),
      );

      expect(cache.contains('$base/only'), isTrue);
    });
  });
}
