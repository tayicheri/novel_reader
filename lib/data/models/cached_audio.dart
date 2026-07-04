import 'package:hive/hive.dart';

import '../repositories/settings_repository.dart';

class CachedAudio {
  CachedAudio({
    required this.sourceUrl,
    required this.engine,
    required this.segmentPaths,
    required this.durationMs,
    DateTime? cachedAt,
  }) : cachedAt = cachedAt ?? DateTime.now();

  final String sourceUrl;
  final TtsEngine engine;
  final List<String> segmentPaths;
  final int durationMs;
  final DateTime cachedAt;

  String get cacheKey => AudioCacheKey.build(sourceUrl, engine);
}

class AudioCacheKey {
  static String build(String sourceUrl, TtsEngine engine) {
    return '$sourceUrl::${engine.name}';
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

    return CachedAudio(
      sourceUrl: sourceUrl,
      engine: TtsEngine.values.byName(engineName),
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
      ..writeInt(obj.cachedAt.millisecondsSinceEpoch);
  }
}
