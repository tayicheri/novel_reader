import 'package:hive/hive.dart';

import '../../core/cloud_narration_styles.dart';
import '../repositories/settings_repository.dart';

class CachedAudio {
  CachedAudio({
    required this.sourceUrl,
    required this.engine,
    required this.segmentPaths,
    required this.durationMs,
    this.cloudProvider,
    this.cloudVoice,
    this.narrationStyle,
    DateTime? cachedAt,
  }) : cachedAt = cachedAt ?? DateTime.now();

  final String sourceUrl;
  final TtsEngine engine;
  final CloudTtsProvider? cloudProvider;
  final String? cloudVoice;
  final CloudNarrationStyle? narrationStyle;
  final List<String> segmentPaths;
  final int durationMs;
  final DateTime cachedAt;

  String get cacheKey => AudioCacheKey.build(
        sourceUrl,
        engine,
        cloudProvider: cloudProvider,
        cloudVoice: cloudVoice,
        narrationStyle: narrationStyle,
      );
}

class AudioCacheKey {
  static String build(
    String sourceUrl,
    TtsEngine engine, {
    CloudTtsProvider? cloudProvider,
    String? cloudVoice,
    CloudNarrationStyle? narrationStyle,
  }) {
    if (engine == TtsEngine.native) {
      return '$sourceUrl::native';
    }
    final provider = cloudProvider ?? CloudTtsProvider.openai;
    final voice = cloudVoice ?? '';
    final style = narrationStyle?.name ?? '';
    return '$sourceUrl::cloud::${provider.name}::$voice::$style';
  }

  /// Ancien format avant multi-fournisseur cloud.
  static String legacyCloud(String sourceUrl) => '$sourceUrl::cloud';

  /// Format avant voix et style de narration.
  static String legacyCloudProvider(String sourceUrl, CloudTtsProvider provider) {
    return '$sourceUrl::cloud::${provider.name}';
  }
}

class CachedAudioAdapter extends TypeAdapter<CachedAudio> {
  @override
  final int typeId = 2;

  @override
  CachedAudio read(BinaryReader reader) {
    final sourceUrl = reader.readString();
    final engineName = reader.readString();
    final segmentCount = reader.readInt();
    final segmentPaths = List<String>.generate(
      segmentCount,
      (_) => reader.readString(),
    );
    final durationMs = reader.readInt();
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());

    CloudTtsProvider? cloudProvider;
    if (reader.availableBytes > 0) {
      final providerName = reader.readString();
      if (providerName.isNotEmpty) {
        cloudProvider = CloudTtsProvider.values.byName(providerName);
      }
    } else if (engineName == TtsEngine.cloud.name) {
      cloudProvider = CloudTtsProvider.openai;
    }

    String? cloudVoice;
    if (reader.availableBytes > 0) {
      final voice = reader.readString();
      if (voice.isNotEmpty) {
        cloudVoice = voice;
      }
    }

    CloudNarrationStyle? narrationStyle;
    if (reader.availableBytes > 0) {
      final styleName = reader.readString();
      if (styleName.isNotEmpty) {
        narrationStyle = normalizeCloudNarrationStyle(styleName);
      }
    }

    return CachedAudio(
      sourceUrl: sourceUrl,
      engine: TtsEngine.values.byName(engineName),
      cloudProvider: cloudProvider,
      cloudVoice: cloudVoice,
      narrationStyle: narrationStyle,
      segmentPaths: segmentPaths,
      durationMs: durationMs,
      cachedAt: cachedAt,
    );
  }

  @override
  void write(BinaryWriter writer, CachedAudio obj) {
    writer
      ..writeString(obj.sourceUrl)
      ..writeString(obj.engine.name)
      ..writeInt(obj.segmentPaths.length);
    for (final path in obj.segmentPaths) {
      writer.writeString(path);
    }
    writer
      ..writeInt(obj.durationMs)
      ..writeInt(obj.cachedAt.millisecondsSinceEpoch)
      ..writeString(obj.cloudProvider?.name ?? '')
      ..writeString(obj.cloudVoice ?? '')
      ..writeString(obj.narrationStyle?.name ?? '');
  }
}
