import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:tayi_whisper/data/models/cached_chapter.dart';
import 'package:tayi_whisper/data/repositories/pages_cache_repository.dart';
import 'package:tayi_whisper/services/novel_extractor.dart';

void main() {
  group('PagesCacheRepository', () {
    late Box<CachedChapter> box;
    late PagesCacheRepository repository;

    setUp(() async {
      Hive.init('./.dart_tool/test_pages_cache_hive');
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(CachedChapterAdapter());
      }
      box = await Hive.openBox<CachedChapter>('pages_cache_test');
      await box.clear();
      repository = PagesCacheRepository.test();
      repository.init(box: box);
    });

    tearDown(() async {
      await box.clear();
      await box.close();
    });

    test('put et get un chapitre', () async {
      const chapter = NovelChapter(
        title: 'Chapitre 1',
        content: 'Contenu du chapitre un avec assez de texte pour passer la validation.',
        sourceUrl: 'https://exemple.com/chapitre-1',
        nextUrl: 'https://exemple.com/chapitre-2',
      );

      await repository.put(chapter);

      final cached = repository.get('https://exemple.com/chapitre-1');
      expect(cached?.title, 'Chapitre 1');
      expect(cached?.nextUrl, 'https://exemple.com/chapitre-2');
    });

    test('delete retire une entrée', () async {
      const chapter = NovelChapter(
        title: 'À supprimer',
        content: 'Contenu du chapitre avec assez de texte pour passer la validation.',
        sourceUrl: 'https://exemple.com/chapitre-x',
      );

      await repository.put(chapter);
      await repository.delete('https://exemple.com/chapitre-x');

      expect(repository.get('https://exemple.com/chapitre-x'), isNull);
    });
  });
}
