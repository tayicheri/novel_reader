import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/hive_boxes.dart';
import 'data/models/cached_audio.dart';
import 'data/models/cached_chapter.dart';
import 'data/models/favorite_work.dart';
import 'data/repositories/audio_cache_repository.dart';
import 'data/repositories/audio_progress_repository.dart';
import 'data/repositories/favorites_repository.dart';
import 'data/repositories/pages_cache_repository.dart';
import 'data/repositories/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(FavoriteWorkAdapter());
  Hive.registerAdapter(CachedChapterAdapter());
  Hive.registerAdapter(CachedAudioAdapter());
  await Hive.openBox<FavoriteWork>(HiveBoxes.favorites);
  await Hive.openBox(HiveBoxes.settings);
  await Hive.openBox<CachedChapter>(HiveBoxes.pages);
  await Hive.openBox<CachedAudio>(HiveBoxes.audioCache);
  await Hive.openBox(HiveBoxes.audioProgress);
  FavoritesRepository.instance.init();
  SettingsRepository.instance.init();
  PagesCacheRepository.instance.init();
  AudioCacheRepository.instance.init();
  AudioProgressRepository.instance.init();
  runApp(const TayiWhisperApp());
}
