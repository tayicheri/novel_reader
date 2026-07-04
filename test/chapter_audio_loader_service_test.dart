import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:tayi_whisper/data/models/cached_audio.dart';
import 'package:tayi_whisper/data/models/cached_chapter.dart';
import 'package:tayi_whisper/data/repositories/audio_cache_repository.dart';
import 'package:tayi_whisper/data/repositories/pages_cache_repository.dart';
import 'package:tayi_whisper/data/repositories/settings_repository.dart';
import 'package:tayi_whisper/services/chapter_audio_loader_service.dart';
import 'package:tayi_whisper/services/chapter_loader_service.dart';
import 'package:tayi_whisper/services/novel_extractor.dart';
import 'package:tayi_whisper/services/tts/progressive_audio_session.dart';
import 'package:tayi_whisper/services/tts/tts_provider.dart';
import 'package:tayi_whisper/services/tts/tts_synthesis_service.dart';

class _FakeProvider implements TtsProvider {
  @override
  Future<String> synthesizeChunk({
    required String text,
    required String outputPath,
  }) async =>
      outputPath;

  @override
  Future<List<String>> synthesizeToFiles({
    required String text,
    required String outputDir,
    required String baseName,
  }) async =>
      ['$outputDir/${baseName}_0.wav'];
}

class _FakeSynthesis implements ChapterAudioSynthesis {
  _FakeSynthesis(this._audioCache);

  final AudioCacheRepository _audioCache;
  int callCount = 0;

  @override
  Future<CachedAudio?> getCached(String sourceUrl) async {
    return _audioCache.get(sourceUrl, TtsEngine.native);
  }

  @override
  Future<ProgressiveAudioSession> createSession({
    required String sourceUrl,
    required String text,
  }) async {
    callCount++;
    return ProgressiveAudioSession(
      sourceUrl: sourceUrl,
      engine: TtsEngine.native,
      outputDir: '/tmp',
      baseName: sourceUrl.hashCode.toString(),
      chunks: ['chunk'],
      provider: _FakeProvider(),
      segmentExtension: 'wav',
    );
  }

  @override
  Future<CachedAudio> saveSession(
    ProgressiveAudioSession session, {
    required int durationMs,
  }) async {
    final audio = CachedAudio(
      sourceUrl: session.sourceUrl,
      engine: session.engine,
      segmentPaths: session.segmentPaths,
      durationMs: durationMs,
    );
    await _audioCache.put(audio);
    return audio;
  }

  @override
  Future<CachedAudio> synthesize({
    required String sourceUrl,
    required String text,
  }) async {
    callCount++;
    final session = await createSession(sourceUrl: sourceUrl, text: text);
    await session.synthesizeNext();
    return saveSession(session, durationMs: 1000);
  }
}

NovelChapter _chapter({
  required String url,
  String? previousUrl,
  String? nextUrl,
  String content = 'Contenu suffisamment long pour les tests audio du chapitre.',
}) {
  return NovelChapter(
    title: 'Titre $url',
    content: content,
    sourceUrl: url,
    previousUrl: previousUrl,
    nextUrl: nextUrl,
  );
}

CachedAudio _audio(String url, {TtsEngine engine = TtsEngine.native}) {
  return CachedAudio(
    sourceUrl: url,
    engine: engine,
    segmentPaths: ['/tmp/$url.wav'],
    durationMs: 1000,
  );
}

void main() {
  group('ChapterAudioLoaderService', () {
    late Box<CachedAudio> audioBox;
    late Box<CachedChapter> pagesBox;
    late AudioCacheRepository audioCache;
    late PagesCacheRepository pagesCache;
    late _FakeSynthesis synthesis;
    late ChapterAudioLoaderService loader;

    const base = 'https://exemple.com';

    setUp(() async {
      Hive.init('./.dart_tool/test_audio_loader_hive');
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(CachedChapterAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(CachedAudioAdapter());
      }
      audioBox = await Hive.openBox<CachedAudio>('audio_loader_audio');
      pagesBox = await Hive.openBox<CachedChapter>('audio_loader_pages');
      final settingsBox = await Hive.openBox('settings_audio_loader_test');
      await settingsBox.clear();
      SettingsRepository.instance.init(box: settingsBox);
      await audioBox.clear();
      await pagesBox.clear();

      audioCache = AudioCacheRepository.test();
      audioCache.init(box: audioBox);
      pagesCache = PagesCacheRepository.test();
      pagesCache.init(box: pagesBox);

      synthesis = _FakeSynthesis(audioCache);

      loader = ChapterAudioLoaderService(
        synthesis: synthesis,
        audioCache: audioCache,
        pagesCache: pagesCache,
        chapterLoader: ChapterLoaderService(
          extractor: NovelExtractorService(),
          cache: pagesCache,
        ),
      );
    });

    tearDown(() async {
      await audioBox.clear();
      await audioBox.close();
      await pagesBox.clear();
      await pagesBox.close();
    });

    test('getCachedAudio utilise le cache', () async {
      await audioCache.put(_audio('$base/cached'));

      final chapter = _chapter(url: '$base/cached');
      final result = await loader.getCachedAudio(chapter);

      expect(result?.sourceUrl, '$base/cached');
      expect(synthesis.callCount, 0);
    });

    test('createPlaybackSession synthétise à la demande', () async {
      final chapter = _chapter(url: '$base/new');
      final session = await loader.createPlaybackSession(chapter);

      expect(session.totalChunks, 1);
      expect(synthesis.callCount, 1);
    });

    test('evictBehindAudio conserve 3 chapitres audio', () async {
      for (var i = 1; i <= 6; i++) {
        final url = '$base/back-$i';
        await audioCache.put(_audio(url));
        await pagesCache.put(
          _chapter(
            url: url,
            previousUrl: i > 1 ? '$base/back-${i - 1}' : null,
            nextUrl: i < 6 ? '$base/back-${i + 1}' : null,
          ),
        );
      }

      await loader.evictBehindAudio(
        _chapter(url: '$base/current', previousUrl: '$base/back-6'),
      );

      expect(audioCache.contains('$base/back-6', TtsEngine.native), isTrue);
      expect(audioCache.contains('$base/back-4', TtsEngine.native), isTrue);
      expect(audioCache.contains('$base/back-3', TtsEngine.native), isFalse);
    });
  });
}
