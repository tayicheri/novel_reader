import 'package:hive_flutter/hive_flutter.dart';

import '../../core/hive_boxes.dart';
import '../../services/novel_extractor.dart';
import '../models/cached_chapter.dart';

class PagesCacheRepository {
  PagesCacheRepository._();

  static final PagesCacheRepository instance = PagesCacheRepository._();

  factory PagesCacheRepository.test() => PagesCacheRepository._();

  Box<CachedChapter>? _box;

  void init({Box<CachedChapter>? box}) {
    _box = box;
  }

  Box<CachedChapter> get box {
    final resolved = _box ?? Hive.box<CachedChapter>(HiveBoxes.pages);
    _box ??= resolved;
    return resolved;
  }

  String normalizeUrl(String rawUrl) => normalizeNovelUrl(rawUrl).toString();

  NovelChapter? get(String rawUrl) {
    final key = normalizeUrl(rawUrl);
    return box.get(key)?.toNovelChapter();
  }

  bool contains(String rawUrl) => box.containsKey(normalizeUrl(rawUrl));

  Future<void> put(NovelChapter chapter) async {
    await box.put(
      chapter.sourceUrl,
      CachedChapter.fromNovelChapter(chapter),
    );
  }

  Future<void> delete(String rawUrl) async {
    await box.delete(normalizeUrl(rawUrl));
  }
}
