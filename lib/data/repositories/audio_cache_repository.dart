import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/hive_boxes.dart';
import '../../services/novel_extractor.dart';
import '../models/cached_audio.dart';
import 'settings_repository.dart';

class AudioCacheRepository {
  AudioCacheRepository._();

  static final AudioCacheRepository instance = AudioCacheRepository._();

  factory AudioCacheRepository.test() => AudioCacheRepository._();

  Box<CachedAudio>? _box;
  String? _audioDir;

  void init({Box<CachedAudio>? box}) {
    _box = box;
  }

  Box<CachedAudio> get box {
    final resolved = _box ?? Hive.box<CachedAudio>(HiveBoxes.audioCache);
    _box ??= resolved;
    return resolved;
  }

  Future<String> audioDirectory() async {
    if (_audioDir != null) return _audioDir!;
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/audio_cache');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    _audioDir = dir.path;
    return _audioDir!;
  }

  String normalizeUrl(String rawUrl) => normalizeNovelUrl(rawUrl).toString();

  CachedAudio? get(String rawUrl, TtsEngine engine) {
    final key = AudioCacheKey.build(normalizeUrl(rawUrl), engine);
    return box.get(key);
  }

  bool contains(String rawUrl, TtsEngine engine) {
    return box.containsKey(AudioCacheKey.build(normalizeUrl(rawUrl), engine));
  }

  Future<void> put(CachedAudio audio) async {
    await box.put(audio.cacheKey, audio);
  }

  Future<void> delete(String rawUrl, {TtsEngine? engine}) async {
    final normalized = normalizeUrl(rawUrl);
    if (engine != null) {
      await _deleteEntry(AudioCacheKey.build(normalized, engine));
      return;
    }

    for (final entry in box.values.toList()) {
      if (entry.sourceUrl == normalized) {
        await _deleteEntry(entry.cacheKey);
      }
    }
  }

  Future<void> _deleteEntry(String key) async {
    final entry = box.get(key);
    if (entry != null) {
      for (final path in entry.segmentPaths) {
        final file = File(path);
        if (file.existsSync()) {
          await file.delete();
        }
      }
    }
    await box.delete(key);
  }

  String baseNameFor(String sourceUrl, TtsEngine engine) {
    final normalized = normalizeUrl(sourceUrl);
    return '${normalized.hashCode}_${engine.name}';
  }
}
