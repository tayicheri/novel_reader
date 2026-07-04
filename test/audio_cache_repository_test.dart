import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:tayi_whisper/data/models/cached_audio.dart';
import 'package:tayi_whisper/data/repositories/audio_cache_repository.dart';
import 'package:tayi_whisper/data/repositories/settings_repository.dart';

void main() {
  group('AudioCacheRepository', () {
    late Box<CachedAudio> box;
    late AudioCacheRepository repository;
    late Directory tempDir;

    setUp(() async {
      Hive.init('./.dart_tool/test_audio_cache_hive');
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(CachedAudioAdapter());
      }
      box = await Hive.openBox<CachedAudio>('audio_cache_test');
      await box.clear();
      repository = AudioCacheRepository.test();
      repository.init(box: box);
      tempDir = await Directory.systemTemp.createTemp('audio_cache_test');
    });

    tearDown(() async {
      await box.clear();
      await box.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('put et get un audio cache', () async {
      final file = File('${tempDir.path}/sample.wav');
      await file.writeAsString('audio');

      final cached = CachedAudio(
        sourceUrl: 'https://exemple.com/ch-1',
        engine: TtsEngine.native,
        segmentPaths: [file.path],
        durationMs: 1200,
      );

      await repository.put(cached);

      final loaded = repository.get('https://exemple.com/ch-1', TtsEngine.native);
      expect(loaded?.durationMs, 1200);
      expect(loaded?.segmentPaths.first, file.path);
    });

    test('delete supprime les fichiers', () async {
      final file = File('${tempDir.path}/delete_me.wav');
      await file.writeAsString('audio');

      final cached = CachedAudio(
        sourceUrl: 'https://exemple.com/ch-x',
        engine: TtsEngine.native,
        segmentPaths: [file.path],
        durationMs: 500,
      );
      await repository.put(cached);

      await repository.delete('https://exemple.com/ch-x');

      expect(repository.get('https://exemple.com/ch-x', TtsEngine.native), isNull);
      expect(file.existsSync(), isFalse);
    });
  });
}
