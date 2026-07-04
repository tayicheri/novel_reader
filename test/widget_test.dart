import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:tayi_whisper/app.dart';
import 'package:tayi_whisper/core/hive_boxes.dart';
import 'package:tayi_whisper/data/models/cached_audio.dart';
import 'package:tayi_whisper/data/models/cached_chapter.dart';
import 'package:tayi_whisper/data/models/favorite_work.dart';
import 'package:tayi_whisper/data/repositories/audio_cache_repository.dart';
import 'package:tayi_whisper/data/repositories/audio_progress_repository.dart';
import 'package:tayi_whisper/data/repositories/favorites_repository.dart';
import 'package:tayi_whisper/data/repositories/pages_cache_repository.dart';
import 'package:tayi_whisper/data/repositories/settings_repository.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Hive.init('./.dart_tool/widget_test_hive');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(FavoriteWorkAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(CachedChapterAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(CachedAudioAdapter());
    }
    if (Hive.isBoxOpen(HiveBoxes.favorites)) {
      await Hive.box<FavoriteWork>(HiveBoxes.favorites).clear();
    } else {
      await Hive.openBox<FavoriteWork>(HiveBoxes.favorites);
    }
    if (Hive.isBoxOpen(HiveBoxes.settings)) {
      await Hive.box(HiveBoxes.settings).clear();
    } else {
      await Hive.openBox(HiveBoxes.settings);
    }
    if (Hive.isBoxOpen(HiveBoxes.pages)) {
      await Hive.box<CachedChapter>(HiveBoxes.pages).clear();
    } else {
      await Hive.openBox<CachedChapter>(HiveBoxes.pages);
    }
    if (Hive.isBoxOpen(HiveBoxes.audioCache)) {
      await Hive.box<CachedAudio>(HiveBoxes.audioCache).clear();
    } else {
      await Hive.openBox<CachedAudio>(HiveBoxes.audioCache);
    }
    if (Hive.isBoxOpen(HiveBoxes.audioProgress)) {
      await Hive.box(HiveBoxes.audioProgress).clear();
    } else {
      await Hive.openBox(HiveBoxes.audioProgress);
    }
    FavoritesRepository.instance.init();
    SettingsRepository.instance.init();
    PagesCacheRepository.instance.init();
    AudioCacheRepository.instance.init();
    AudioProgressRepository.instance.init();
  });

  testWidgets('Tayi Whisper home screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const TayiWhisperApp());
    await tester.pumpAndSettle();

    expect(find.text('Tayi Whisper'), findsOneWidget);
    expect(find.text('Charger'), findsOneWidget);
    expect(find.text('Mes favoris'), findsOneWidget);
  });
}
