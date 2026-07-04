import 'package:just_audio/just_audio.dart';

import '../../core/cloud_narration_styles.dart';
import '../../data/models/cached_audio.dart';
import '../../data/repositories/audio_cache_repository.dart';
import '../../data/repositories/settings_repository.dart';
import 'cloud/cloud_tts_factory.dart';
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

  /// Supprime le cache et annule une synthèse en cours pour ce chapitre.
  Future<void> invalidateForReload(String sourceUrl);

  @Deprecated('Use createSession + progressive playback')
  Future<CachedAudio> synthesize({
    required String sourceUrl,
    required String text,
  });
}

typedef CloudTtsProviderFactory = TtsProvider Function({
  required CloudTtsProvider provider,
  required String apiKey,
  required String voice,
  required CloudNarrationStyle narrationStyle,
});

class TtsSynthesisService implements ChapterAudioSynthesis {
  TtsSynthesisService({
    SettingsRepository? settings,
    AudioCacheRepository? audioCache,
    NativeTtsProvider? nativeProvider,
    CloudTtsProviderFactory? cloudProviderFactory,
  })  : _settings = settings ?? SettingsRepository.instance,
        _audioCache = audioCache ?? AudioCacheRepository.instance,
        _nativeProvider = nativeProvider ??
            NativeTtsProvider(
              languageCode: () =>
                  (settings ?? SettingsRepository.instance).ttsLanguage,
            ),
        _cloudProviderFactory =
            cloudProviderFactory ?? CloudTtsFactory.create;

  final SettingsRepository _settings;
  final AudioCacheRepository _audioCache;
  final NativeTtsProvider _nativeProvider;
  final CloudTtsProviderFactory _cloudProviderFactory;
  final Map<String, Future<ProgressiveAudioSession>> _inFlightSessions = {};

  @override
  Future<CachedAudio?> getCached(String sourceUrl) async {
    final engine = await _settings.resolveEffectiveEngine();
    final cloudProvider = await _settings.resolveEffectiveCloudProvider();
    final cloudVoice = _cloudVoice(cloudProvider);
    final narrationStyle = _cloudNarrationStyle(cloudProvider);
    final cached = _audioCache.get(
      sourceUrl,
      engine,
      cloudProvider: cloudProvider,
      cloudVoice: cloudVoice,
      narrationStyle: narrationStyle,
    );
    if (cached != null && !_cacheMatchesSettings(
      cached,
      engine: engine,
      cloudProvider: cloudProvider,
      cloudVoice: cloudVoice,
      narrationStyle: narrationStyle,
    )) {
      return null;
    }
    return cached;
  }

  bool _cacheMatchesSettings(
    CachedAudio cached, {
    required TtsEngine engine,
    required CloudTtsProvider? cloudProvider,
    required String? cloudVoice,
    required CloudNarrationStyle? narrationStyle,
  }) {
    if (cached.engine != engine) return false;
    if (engine != TtsEngine.cloud) return true;
    return cached.cloudProvider == cloudProvider &&
        cached.cloudVoice == cloudVoice &&
        cached.narrationStyle == narrationStyle;
  }

  @override
  Future<ProgressiveAudioSession> createSession({
    required String sourceUrl,
    required String text,
  }) async {
    final engine = await _settings.resolveEffectiveEngine();
    final cloudProvider = await _settings.resolveEffectiveCloudProvider();
    final cloudVoice = _cloudVoice(cloudProvider);
    final narrationStyle = _cloudNarrationStyle(cloudProvider);
    final normalized = _audioCache.normalizeUrl(sourceUrl);
    final key = AudioCacheKey.build(
      normalized,
      engine,
      cloudProvider: cloudProvider,
      cloudVoice: cloudVoice,
      narrationStyle: narrationStyle,
    );

    final cached = _audioCache.get(
      sourceUrl,
      engine,
      cloudProvider: cloudProvider,
      cloudVoice: cloudVoice,
      narrationStyle: narrationStyle,
    );
    if (cached != null) {
      throw StateError('Audio déjà en cache pour $sourceUrl');
    }

    final existing = _inFlightSessions[key];
    if (existing != null) return existing;

    final future = _buildSession(
      sourceUrl: sourceUrl,
      text: text,
      engine: engine,
      cloudProvider: cloudProvider,
      cloudVoice: cloudVoice,
      narrationStyle: narrationStyle,
    );
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
    required CloudTtsProvider? cloudProvider,
    required String? cloudVoice,
    required CloudNarrationStyle? narrationStyle,
  }) async {
    final outputDir = await _audioCache.audioDirectory();
    final baseName = _audioCache.baseNameFor(
      sourceUrl,
      engine,
      cloudProvider: cloudProvider,
      cloudVoice: cloudVoice,
      narrationStyle: narrationStyle,
    );
    final chunks = splitTextChunks(text);
    final provider = _providerFor(
      engine,
      cloudProvider,
      cloudVoice: cloudVoice,
      narrationStyle: narrationStyle,
    );

    return ProgressiveAudioSession(
      sourceUrl: _audioCache.normalizeUrl(sourceUrl),
      engine: engine,
      cloudProvider: cloudProvider,
      cloudVoice: cloudVoice,
      narrationStyle: narrationStyle,
      outputDir: outputDir,
      baseName: baseName,
      chunks: chunks,
      provider: provider,
      segmentExtension: segmentExtensionFor(
        engine,
        cloudProvider: cloudProvider,
      ),
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
      cloudProvider: session.cloudProvider,
      cloudVoice: session.cloudVoice,
      narrationStyle: session.narrationStyle,
      segmentPaths: session.segmentPaths,
      durationMs: durationMs,
    );
    await _audioCache.put(cached);
    return cached;
  }

  @override
  Future<void> invalidateForReload(String sourceUrl) async {
    final engine = await _settings.resolveEffectiveEngine();
    final cloudProvider = await _settings.resolveEffectiveCloudProvider();
    final key = AudioCacheKey.build(
      _audioCache.normalizeUrl(sourceUrl),
      engine,
      cloudProvider: cloudProvider,
      cloudVoice: _cloudVoice(cloudProvider),
      narrationStyle: _cloudNarrationStyle(cloudProvider),
    );
    _inFlightSessions.remove(key);
    await _audioCache.delete(sourceUrl);
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

  String? _cloudVoice(CloudTtsProvider? cloudProvider) {
    if (cloudProvider == null) return null;
    return _settings.voiceForCloudProvider(cloudProvider);
  }

  CloudNarrationStyle? _cloudNarrationStyle(CloudTtsProvider? cloudProvider) {
    if (cloudProvider == null) return null;
    return _settings.cloudNarrationStyle;
  }

  TtsProvider _providerFor(
    TtsEngine engine,
    CloudTtsProvider? cloudProvider, {
    required String? cloudVoice,
    required CloudNarrationStyle? narrationStyle,
  }) {
    if (engine == TtsEngine.cloud) {
      final provider = cloudProvider ?? _settings.cloudTtsProvider;
      final apiKey = _settings.apiKeyForCloudProvider(provider);
      if (apiKey == null) {
        throw TtsSynthesisException('Clé API cloud manquante.');
      }
      return _cloudProviderFactory(
        provider: provider,
        apiKey: apiKey,
        voice: cloudVoice ?? _settings.voiceForCloudProvider(provider),
        narrationStyle: narrationStyle ?? _settings.cloudNarrationStyle,
      );
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
