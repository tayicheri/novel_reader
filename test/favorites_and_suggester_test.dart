import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:tayi_whisper/data/models/favorite_work.dart';
import 'package:tayi_whisper/data/repositories/favorites_repository.dart';
import 'package:tayi_whisper/services/work_title_suggester.dart';

void main() {
  group('WorkTitleSuggester', () {
    final suggester = WorkTitleSuggester();

    test('retire un suffixe de chapitre', () {
      expect(
        suggester.suggest(chapterTitle: 'Solo Leveling - Chapitre 42'),
        'Solo Leveling',
      );
    });

    test('retire un prefixe de chapitre', () {
      expect(
        suggester.suggest(chapterTitle: 'Chapter 12: My Hero Academia'),
        'My Hero Academia',
      );
    });

    test('utilise le host en fallback', () {
      expect(
        suggester.suggest(
          chapterTitle: '',
          sourceUrl: 'https://www.exemple.com/chapitre-1',
        ),
        'exemple.com',
      );
    });
  });

  group('FavoritesRepository', () {
    late Box<FavoriteWork> box;
    late FavoritesRepository repository;

    setUp(() async {
      Hive.init('./.dart_tool/test_hive');
      if (Hive.isAdapterRegistered(0)) {
        // already registered in same isolate
      } else {
        Hive.registerAdapter(FavoriteWorkAdapter());
      }
      box = await Hive.openBox<FavoriteWork>('favorites_test');
      await box.clear();
      repository = FavoritesRepository.instance;
      repository.init(box: box);
    });

    tearDown(() async {
      await box.clear();
      await box.close();
    });

    test('save et getAll triés par date', () async {
      final first = await repository.save(
        title: 'Première œuvre',
        lastUrl: 'https://exemple.com/1',
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final second = await repository.save(
        title: 'Deuxième œuvre',
        lastUrl: 'https://exemple.com/2',
      );

      final all = repository.getAll();
      expect(all.first.id, second.id);
      expect(all.last.id, first.id);
    });

    test('updateProgress met à jour url et offset', () async {
      final favorite = await repository.save(
        title: 'Œuvre test',
        lastUrl: 'https://exemple.com/a',
      );

      await repository.updateProgress(
        id: favorite.id,
        url: 'https://exemple.com/b',
        scrollOffset: 320,
      );

      final updated = repository.getById(favorite.id);
      expect(updated?.lastUrl, 'https://exemple.com/b');
      expect(updated?.scrollOffset, 320);
    });

    test('delete retire une entrée', () async {
      final favorite = await repository.save(
        title: 'À supprimer',
        lastUrl: 'https://exemple.com/x',
      );

      await repository.delete(favorite.id);
      expect(repository.getById(favorite.id), isNull);
    });
  });
}
