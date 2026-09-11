import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/cloud_narration_styles.dart';
import '../../core/cloud_voice_options.dart';
import '../../core/hive_boxes.dart';
import '../../core/kokoro_voice_options.dart';
import '../../core/tts_language_options.dart';

enum TtsEngine { native, cloud, kokoro }

enum CloudTtsProvider { gemini, openai }

enum ThemePreference { system, light, dark }

class SettingsRepository {
  SettingsRepository._();

  static final SettingsRepository instance = SettingsRepository._();

  static const String _isDarkModeKey = 'isDarkMode';
  static const String _themePreferenceKey = 'themePreference';
  static const String _ttsEngineKey = 'ttsEngine';
  static const String _ttsLanguageKey = 'ttsLanguage';
  static const String _cloudTtsProviderKey = 'cloudTtsProvider';
  static const String _geminiApiKeyKey = 'geminiApiKey';
  static const String _openaiApiKeyKey = 'openaiApiKey';
  static const String _cloudTtsApiKeyKey = 'cloudTtsApiKey';
  static const String _geminiVoiceKey = 'geminiVoice';
  static const String _openaiVoiceKey = 'openaiVoice';
  static const String _cloudNarrationStyleKey = 'cloudNarrationStyle';
  static const String _kokoroVoiceKey = 'kokoroVoice';

  Box? _box;
  final ValueNotifier<ThemePreference> themePreference =
      ValueNotifier(ThemePreference.light);
  final Connectivity _connectivity = Connectivity();

  void init({Box? box}) {
    _box = box;
    themePreference.value = _readThemePreference();
    _migrateLegacyCloudApiKey();
  }

  Box get box {
    final resolved = _box ?? Hive.box(HiveBoxes.settings);
    _box ??= resolved;
    return resolved;
  }

  void _migrateLegacyCloudApiKey() {
    final legacy = box.get(_cloudTtsApiKeyKey);
    if (legacy is! String || legacy.trim().isEmpty) return;

    final existingOpenAi = box.get(_openaiApiKeyKey);
    if (existingOpenAi == null ||
        (existingOpenAi is String && existingOpenAi.isEmpty)) {
      box.put(_openaiApiKeyKey, legacy.trim());
    }
    box.delete(_cloudTtsApiKeyKey);
  }

  ThemePreference _readThemePreference() {
    final stored = box.get(_themePreferenceKey);
    if (stored is String) {
      for (final value in ThemePreference.values) {
        if (value.name == stored) return value;
      }
    }
    final legacy = box.get(_isDarkModeKey);
    if (legacy is bool) {
      return legacy ? ThemePreference.dark : ThemePreference.light;
    }
    return ThemePreference.light;
  }

  Future<void> setThemePreference(ThemePreference value) async {
    await box.put(_themePreferenceKey, value.name);
    themePreference.value = value;
  }

  TtsEngine get ttsEngine {
    final value = box.get(_ttsEngineKey);
    if (value is String) {
      for (final engine in TtsEngine.values) {
        if (engine.name == value) return engine;
      }
    }
    return TtsEngine.native;
  }

  Future<void> setTtsEngine(TtsEngine value) async {
    await box.put(_ttsEngineKey, value.name);
  }

  CloudTtsProvider get cloudTtsProvider {
    final value = box.get(_cloudTtsProviderKey);
    if (value is String) {
      return CloudTtsProvider.values.byName(value);
    }
    return CloudTtsProvider.gemini;
  }

  Future<void> setCloudTtsProvider(CloudTtsProvider value) async {
    await box.put(_cloudTtsProviderKey, value.name);
  }

  String get ttsLanguage {
    final value = box.get(_ttsLanguageKey);
    if (value is String) {
      return normalizeTtsLanguageCode(value);
    }
    return defaultTtsLanguageCode;
  }

  Future<void> setTtsLanguage(String value) async {
    await box.put(_ttsLanguageKey, normalizeTtsLanguageCode(value));
  }

  String? get geminiApiKey => _readApiKey(_geminiApiKeyKey);

  String? get openaiApiKey => _readApiKey(_openaiApiKeyKey);

  Future<void> setGeminiApiKey(String? value) async {
    await _writeApiKey(_geminiApiKeyKey, value);
  }

  Future<void> setOpenaiApiKey(String? value) async {
    await _writeApiKey(_openaiApiKeyKey, value);
  }

  String voiceForCloudProvider(CloudTtsProvider provider) {
    final key = switch (provider) {
      CloudTtsProvider.gemini => _geminiVoiceKey,
      CloudTtsProvider.openai => _openaiVoiceKey,
    };
    final value = box.get(key);
    return normalizeVoiceId(
      provider,
      value is String ? value : null,
    );
  }

  Future<void> setVoiceForCloudProvider(
    CloudTtsProvider provider,
    String voiceId,
  ) async {
    final key = switch (provider) {
      CloudTtsProvider.gemini => _geminiVoiceKey,
      CloudTtsProvider.openai => _openaiVoiceKey,
    };
    await box.put(key, normalizeVoiceId(provider, voiceId));
  }

  CloudNarrationStyle get cloudNarrationStyle {
    final value = box.get(_cloudNarrationStyleKey);
    return normalizeCloudNarrationStyle(value is String ? value : null);
  }

  Future<void> setCloudNarrationStyle(CloudNarrationStyle value) async {
    await box.put(_cloudNarrationStyleKey, value.name);
  }

  String get kokoroVoice {
    final value = box.get(_kokoroVoiceKey);
    return normalizeKokoroVoiceId(
      ttsLanguage,
      value is String ? value : null,
    );
  }

  Future<void> setKokoroVoice(String voiceId) async {
    await box.put(
      _kokoroVoiceKey,
      normalizeKokoroVoiceId(ttsLanguage, voiceId),
    );
  }

  String? apiKeyForCloudProvider(CloudTtsProvider provider) {
    switch (provider) {
      case CloudTtsProvider.gemini:
        return geminiApiKey;
      case CloudTtsProvider.openai:
        return openaiApiKey;
    }
  }

  String? get cloudTtsApiKey => apiKeyForCloudProvider(cloudTtsProvider);

  Future<void> setCloudTtsApiKey(String? value) async {
    switch (cloudTtsProvider) {
      case CloudTtsProvider.gemini:
        await setGeminiApiKey(value);
      case CloudTtsProvider.openai:
        await setOpenaiApiKey(value);
    }
  }

  String? _readApiKey(String key) {
    _migrateLegacyCloudApiKey();
    final value = box.get(key);
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  Future<void> _writeApiKey(String key, String? value) async {
    if (value == null || value.trim().isEmpty) {
      await box.delete(key);
      return;
    }
    await box.put(key, value.trim());
  }

  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  Future<TtsEngine> resolveEffectiveEngine() async {
    switch (ttsEngine) {
      case TtsEngine.native:
        return TtsEngine.native;
      case TtsEngine.kokoro:
        return TtsEngine.kokoro;
      case TtsEngine.cloud:
        if (apiKeyForCloudProvider(cloudTtsProvider) == null) {
          return TtsEngine.native;
        }
        return TtsEngine.cloud;
    }
  }

  Future<CloudTtsProvider?> resolveEffectiveCloudProvider() async {
    final engine = await resolveEffectiveEngine();
    if (engine != TtsEngine.cloud) return null;
    return cloudTtsProvider;
  }
}
