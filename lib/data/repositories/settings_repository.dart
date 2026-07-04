import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/hive_boxes.dart';
import '../../core/tts_language_options.dart';

enum TtsEngine { native, cloud }

class SettingsRepository {
  SettingsRepository._();

  static final SettingsRepository instance = SettingsRepository._();

  static const String _isDarkModeKey = 'isDarkMode';
  static const String _ttsEngineKey = 'ttsEngine';
  static const String _ttsLanguageKey = 'ttsLanguage';
  static const String _cloudTtsApiKeyKey = 'cloudTtsApiKey';

  Box? _box;
  final ValueNotifier<bool> isDarkMode = ValueNotifier(false);
  final Connectivity _connectivity = Connectivity();

  void init({Box? box}) {
    _box = box;
    isDarkMode.value = _readDarkMode();
  }

  Box get box {
    final resolved = _box ?? Hive.box(HiveBoxes.settings);
    _box ??= resolved;
    return resolved;
  }

  bool _readDarkMode() {
    final value = box.get(_isDarkModeKey);
    return value is bool ? value : false;
  }

  Future<void> setDarkMode(bool value) async {
    await box.put(_isDarkModeKey, value);
    isDarkMode.value = value;
  }

  TtsEngine get ttsEngine {
    final value = box.get(_ttsEngineKey);
    if (value is String) {
      return TtsEngine.values.byName(value);
    }
    return TtsEngine.native;
  }

  Future<void> setTtsEngine(TtsEngine value) async {
    await box.put(_ttsEngineKey, value.name);
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

  String? get cloudTtsApiKey {
    final value = box.get(_cloudTtsApiKeyKey);
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  Future<void> setCloudTtsApiKey(String? value) async {
    if (value == null || value.trim().isEmpty) {
      await box.delete(_cloudTtsApiKeyKey);
      return;
    }
    await box.put(_cloudTtsApiKeyKey, value.trim());
  }

  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  Future<TtsEngine> resolveEffectiveEngine() async {
    if (ttsEngine != TtsEngine.cloud) {
      return TtsEngine.native;
    }
    if (cloudTtsApiKey == null) {
      return TtsEngine.native;
    }
    final online = await isOnline();
    return online ? TtsEngine.cloud : TtsEngine.native;
  }
}
