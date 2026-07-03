import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/hive_boxes.dart';
import '../models/favorite_work.dart';

class FavoritesRepository {
  FavoritesRepository._();

  static final FavoritesRepository instance = FavoritesRepository._();

  Box<FavoriteWork>? _box;

  void init({Box<FavoriteWork>? box}) {
    _box = box;
  }

  Box<FavoriteWork> get box {
    final resolved = _box ?? Hive.box<FavoriteWork>(HiveBoxes.favorites);
    _box ??= resolved;
    return resolved;
  }

  ValueListenable<Box<FavoriteWork>> watchFavorites() => box.listenable();

  List<FavoriteWork> getAll() {
    final items = box.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  FavoriteWork? getById(String id) => box.get(id);

  Future<FavoriteWork> save({
    required String title,
    required String lastUrl,
    double scrollOffset = 0,
    String? id,
  }) async {
    final favorite = FavoriteWork(
      id: id ?? const Uuid().v4(),
      title: title.trim(),
      lastUrl: lastUrl,
      scrollOffset: scrollOffset,
      updatedAt: DateTime.now(),
    );
    await box.put(favorite.id, favorite);
    return favorite;
  }

  Future<void> update(FavoriteWork favorite) async {
    await box.put(
      favorite.id,
      favorite.copyWith(updatedAt: DateTime.now()),
    );
  }

  Future<void> updateProgress({
    required String id,
    required String url,
    required double scrollOffset,
  }) async {
    final existing = getById(id);
    if (existing == null) return;

    await box.put(
      id,
      existing.copyWith(
        lastUrl: url,
        scrollOffset: scrollOffset,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> delete(String id) async {
    await box.delete(id);
  }
}
