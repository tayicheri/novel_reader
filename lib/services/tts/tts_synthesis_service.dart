import 'package:just_audio/just_audio.dart';

import '../../data/models/cached_audio.dart';
import '../../data/repositories/audio_cache_repository.dart';
import '../../data/repositories/settings_repository.dart';
import 'cloud_tts_provider.dart';
import 'native_tts_provider.dart';
import 'progressive_audio_session.dart';
import 'tts_provider.dart';

abstract class ChapterAudioSynthesis {
  Future<CachedAudio?> getCached(String sourceUrl);

  Future<ProgressiveAudioSession> createSession({
    required String sourceUrl,
    required String text,
  });

  Future<CachedAudio> saveSession(
    ProgressiveAudioSession session, {
    required int durationMs,
  });

  @Deprecated('Use createSession + progressive playback')
  Future<CachedAudio> synthesize({
    required String sourceUrl,
    required String text,
  });
}

class TtsSynthesisService implements ChapterAudioSynthesis {
  TtsSynthesisService({
    SettingsRepository? settings,
    AudioCacheRepository? audioCache,
    NativeTtsProvider? nativeProvider,
    CloudTtsProvider Function(String apiKey)? cloudProviderFactory,
  })  : _settings = settings ?? SettingsRepository.instance,
        _audioCache = audioCache ?? AudioCacheRepository.instance,
        _nativeProvider = nativeProvider ?? NativeTtsProvider(),
        _cloudProviderFactory =
            cloudProviderFactory ?? ((apiKey) => CloudTtsProvider(apiKey: apiKey));

  final SettingsRepository _settings;
  final AudioCacheRepository _audioCache;
  final NativeTtsProvider _nativeProvider;
  final CloudTtsProvider Function(String apiKey) _cloudProviderFactory;
  final Map<String, Future<ProgressiveAudioSession>> _inFlightSessions = {};

  @override
  Future<CachedAudio?> getCached(String sourceUrl) async {
    final engine = await _settings.resolveEffectiveEngine();
    return _audioCache.get(sourceUrl, engine);
  }

  @override
  Future<ProgressiveAudioSession> createSession({
    required String sourceUrl,
    required String text,
  }) async {
    final engine = await _settings.resolveEffectiveEngine();
    final key = AudioCacheKey.build(_audioCache.normalizeUrl(sourceUrl), engine);

    final cached = _audioCache.get(sourceUrl, engine);
    if (cached != null) {
      throw StateError('Audio déjà en cache pour $sourceUrl');
    }

    final existing = _inFlightSessions[key];
    if (existing != null) return existing;

    final future = _buildSession(sourceUrl: sourceUrl, text: text, engine: engine);
    _inFlightSessions[key] = future;

    try {
      return await future;
    } finally {
      _inFlightSessions.remove(key);
    }
  }

  Future<ProgressiveAudioSession> _buildSession({
    required String sourceUrl,
    required String text,
    required TtsEngine engine,
  }) async {
    final outputDir = await _audioCache.audioDirectory();
    final baseName = _audioCache.baseNameFor(sourceUrl, engine);
    final chunks = splitTextChunks(text);
    final provider = _providerFor(engine);

    return ProgressiveAudioSession(
      sourceUrl: _audioCache.normalizeUrl(sourceUrl),
      engine: engine,
      outputDir: outputDir,
      baseName: baseName,
      chunks: chunks,
      provider: provider,
      segmentExtension: segmentExtensionFor(engine),
    );
  }

  @override
  Future<CachedAudio> saveSession(
    ProgressiveAudioSession session, {
    required int durationMs,
  }) async {
    final cached = CachedAudio(
      sourceUrl: session.sourceUrl,
      engine: session.engine,
      segmentPaths: session.segmentPaths,
      durationMs: durationMs,
    );
    await _audioCache.put(cached);
    return cached;
  }

  @override
  Future<CachedAudio> synthesize({
    required String sourceUrl,
    required String text,
  }) async {
    final cached = await getCached(sourceUrl);
    if (cached != null) return cached;

    final session = await createSession(sourceUrl: sourceUrl, text: text);
    while (!session.isComplete) {
      await session.synthesizeNext();
    }
    final durationMs = await _measureDurationMs(session.segmentPaths);
    return saveSession(session, durationMs: durationMs);
  }

  TtsProvider _providerFor(TtsEngine engine) {
    if (engine == TtsEngine.cloud) {
      final apiKey = _settings.cloudTtsApiKey;
      if (apiKey == null) {
        throw TtsSynthesisException('Clé API cloud manquante.');
      }
      return _cloudProviderFactory(apiKey);
    }
    return _nativeProvider;
  }

  Future<int> _measureDurationMs(List<String> paths) async {
    final player = AudioPlayer();
    var totalMs = 0;
    try {
      for (final path in paths) {
        final duration = await player.setFilePath(path);
        totalMs += duration?.inMilliseconds ?? 0;
      }
    } finally {
      await player.dispose();
    }
    return totalMs;
  }
}
