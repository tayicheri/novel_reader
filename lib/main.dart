import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/hive_boxes.dart';
import 'data/models/favorite_work.dart';
import 'data/repositories/favorites_repository.dart';
import 'data/repositories/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(FavoriteWorkAdapter());
  await Hive.openBox<FavoriteWork>(HiveBoxes.favorites);
  await Hive.openBox(HiveBoxes.settings);
  FavoritesRepository.instance.init();
  SettingsRepository.instance.init();
  runApp(const TayiWhisperApp());
}
