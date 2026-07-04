import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/cloud_narration_styles.dart';
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

  CachedAudio? get(
    String rawUrl,
    TtsEngine engine, {
    CloudTtsProvider? cloudProvider,
    String? cloudVoice,
    CloudNarrationStyle? narrationStyle,
  }) {
    final normalized = normalizeUrl(rawUrl);
    final key = AudioCacheKey.build(
      normalized,
      engine,
      cloudProvider: cloudProvider,
      cloudVoice: cloudVoice,
      narrationStyle: narrationStyle,
    );
    final cached = box.get(key);
    if (cached != null) return cached;

    if (engine == TtsEngine.cloud && cloudProvider != null) {
      final useLegacyFallback =
          (cloudVoice == null || cloudVoice.isEmpty) &&
              narrationStyle == null;
      if (!useLegacyFallback) return null;

      final legacyProviderKey = AudioCacheKey.legacyCloudProvider(
        normalized,
        cloudProvider,
      );
      final legacyProviderEntry = box.get(legacyProviderKey);
      if (legacyProviderEntry != null) return legacyProviderEntry;

      return box.get(AudioCacheKey.legacyCloud(normalized));
    }
    return null;
  }

  bool contains(
    String rawUrl,
    TtsEngine engine, {
    CloudTtsProvider? cloudProvider,
    String? cloudVoice,
    CloudNarrationStyle? narrationStyle,
  }) {
    return get(
      rawUrl,
      engine,
      cloudProvider: cloudProvider,
      cloudVoice: cloudVoice,
      narrationStyle: narrationStyle,
    ) != null;
  }

  Future<void> put(CachedAudio audio) async {
    await box.put(audio.cacheKey, audio);
    if (audio.engine == TtsEngine.cloud) {
      await box.delete(AudioCacheKey.legacyCloud(audio.sourceUrl));
      if (audio.cloudProvider != null) {
        await box.delete(
          AudioCacheKey.legacyCloudProvider(
            audio.sourceUrl,
            audio.cloudProvider!,
          ),
        );
      }
    }
  }

  Future<void> delete(String rawUrl, {TtsEngine? engine}) async {
    final normalized = normalizeUrl(rawUrl);
    if (engine != null) {
      if (engine == TtsEngine.cloud) {
        for (final provider in CloudTtsProvider.values) {
          await _deleteEntry(
            AudioCacheKey.build(normalized, engine, cloudProvider: provider),
          );
          await _deleteEntry(
            AudioCacheKey.legacyCloudProvider(normalized, provider),
          );
        }
        await _deleteEntry(AudioCacheKey.legacyCloud(normalized));
      } else {
        await _deleteEntry(AudioCacheKey.build(normalized, engine));
      }
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

  String baseNameFor(
    String sourceUrl,
    TtsEngine engine, {
    CloudTtsProvider? cloudProvider,
    String? cloudVoice,
    CloudNarrationStyle? narrationStyle,
  }) {
    final normalized = normalizeUrl(sourceUrl);
    if (engine == TtsEngine.native) {
      return '${normalized.hashCode}_native';
    }
    final provider = cloudProvider ?? CloudTtsProvider.openai;
    final voice = cloudVoice ?? '';
    final style = narrationStyle?.name ?? '';
    return '${normalized.hashCode}_cloud_${provider.name}_${voice}_$style';
  }
}
