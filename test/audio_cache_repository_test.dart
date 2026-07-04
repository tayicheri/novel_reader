import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:tayi_whisper/core/cloud_narration_styles.dart';
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

    test('sépare le cache cloud par fournisseur', () async {
      final geminiFile = File('${tempDir.path}/gemini.wav');
      final openaiFile = File('${tempDir.path}/openai.mp3');
      await geminiFile.writeAsString('gemini');
      await openaiFile.writeAsString('openai');

      await repository.put(
        CachedAudio(
          sourceUrl: 'https://exemple.com/ch-cloud',
          engine: TtsEngine.cloud,
          cloudProvider: CloudTtsProvider.gemini,
          segmentPaths: [geminiFile.path],
          durationMs: 1000,
        ),
      );
      await repository.put(
        CachedAudio(
          sourceUrl: 'https://exemple.com/ch-cloud',
          engine: TtsEngine.cloud,
          cloudProvider: CloudTtsProvider.openai,
          segmentPaths: [openaiFile.path],
          durationMs: 2000,
        ),
      );

      final gemini = repository.get(
        'https://exemple.com/ch-cloud',
        TtsEngine.cloud,
        cloudProvider: CloudTtsProvider.gemini,
      );
      final openai = repository.get(
        'https://exemple.com/ch-cloud',
        TtsEngine.cloud,
        cloudProvider: CloudTtsProvider.openai,
      );

      expect(gemini?.durationMs, 1000);
      expect(openai?.durationMs, 2000);
    });

    test('sépare le cache cloud par voix et style', () async {
      final koreFile = File('${tempDir.path}/kore.wav');
      final charonFile = File('${tempDir.path}/charon.wav');
      await koreFile.writeAsString('kore');
      await charonFile.writeAsString('charon');

      await repository.put(
        CachedAudio(
          sourceUrl: 'https://exemple.com/ch-voice',
          engine: TtsEngine.cloud,
          cloudProvider: CloudTtsProvider.gemini,
          cloudVoice: 'Kore',
          narrationStyle: CloudNarrationStyle.audiobook,
          segmentPaths: [koreFile.path],
          durationMs: 1100,
        ),
      );
      await repository.put(
        CachedAudio(
          sourceUrl: 'https://exemple.com/ch-voice',
          engine: TtsEngine.cloud,
          cloudProvider: CloudTtsProvider.gemini,
          cloudVoice: 'Charon',
          narrationStyle: CloudNarrationStyle.dramatic,
          segmentPaths: [charonFile.path],
          durationMs: 2200,
        ),
      );

      final kore = repository.get(
        'https://exemple.com/ch-voice',
        TtsEngine.cloud,
        cloudProvider: CloudTtsProvider.gemini,
        cloudVoice: 'Kore',
        narrationStyle: CloudNarrationStyle.audiobook,
      );
      final charon = repository.get(
        'https://exemple.com/ch-voice',
        TtsEngine.cloud,
        cloudProvider: CloudTtsProvider.gemini,
        cloudVoice: 'Charon',
        narrationStyle: CloudNarrationStyle.dramatic,
      );

      expect(kore?.durationMs, 1100);
      expect(charon?.durationMs, 2200);
    });

    test('ignore legacy cache quand voix explicite', () async {
      final legacyFile = File('${tempDir.path}/legacy.wav');
      await legacyFile.writeAsString('legacy');

      await repository.put(
        CachedAudio(
          sourceUrl: 'https://exemple.com/ch-legacy',
          engine: TtsEngine.cloud,
          cloudProvider: CloudTtsProvider.gemini,
          segmentPaths: [legacyFile.path],
          durationMs: 900,
        ),
      );
      await box.put(
        AudioCacheKey.legacyCloudProvider(
          'https://exemple.com/ch-legacy',
          CloudTtsProvider.gemini,
        ),
        CachedAudio(
          sourceUrl: 'https://exemple.com/ch-legacy',
          engine: TtsEngine.cloud,
          cloudProvider: CloudTtsProvider.gemini,
          segmentPaths: [legacyFile.path],
          durationMs: 900,
        ),
      );

      final result = repository.get(
        'https://exemple.com/ch-legacy',
        TtsEngine.cloud,
        cloudProvider: CloudTtsProvider.gemini,
        cloudVoice: 'Charon',
        narrationStyle: CloudNarrationStyle.audiobook,
      );

      expect(result, isNull);
    });
  });
}
