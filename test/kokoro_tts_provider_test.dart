import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:tayi_whisper/data/repositories/settings_repository.dart';
import 'package:tayi_whisper/services/tts/kokoro/kokoro_runtime.dart';
import 'package:tayi_whisper/services/tts/kokoro_tts_provider.dart';
import 'package:tayi_whisper/services/tts/wav_encoder.dart';

class _FakeKokoroRuntime implements KokoroRuntime {
  @override
  int get sampleRate => 24000;

  @override
  Future<void> ensureReady() async {}

  @override
  Future<List<double>> generate({
    required String text,
    required String voice,
    required String languageCode,
  }) async {
    return List<double>.filled(240, 0.1);
  }
}

void main() {
  test('float32ToWav produit un en-tête RIFF', () {
    final wav = float32ToWav(const [0.0, 0.5, -0.5], sampleRate: 24000);
    expect(wav.length, 44 + 6);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
  });

  group('KokoroTtsProvider', () {
    late Box settingsBox;
    late Directory tempDir;

    setUp(() async {
      Hive.init('./.dart_tool/test_kokoro_hive');
      settingsBox = await Hive.openBox('kokoro_settings');
      await settingsBox.clear();
      SettingsRepository.instance.init(box: settingsBox);
      tempDir = await Directory.systemTemp.createTemp('kokoro_tts');
    });

    tearDown(() async {
      await settingsBox.clear();
      await settingsBox.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('écrit un WAV via le runtime injecté', () async {
      final provider = KokoroTtsProvider(
        settings: SettingsRepository.instance,
        runtime: _FakeKokoroRuntime(),
      );
      final path = '${tempDir.path}/chunk.wav';
      await provider.synthesizeChunk(text: 'Bonjour', outputPath: path);

      final bytes = await File(path).readAsBytes();
      expect(bytes.length, greaterThan(44));
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    });
  });
}
