import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/services.dart';

import 'package:tayi_whisper/core/cloud_narration_styles.dart';
import 'package:tayi_whisper/data/repositories/settings_repository.dart';
import 'package:tayi_whisper/services/tts/cloud/cloud_voice_preview_service.dart';
import 'package:tayi_whisper/services/tts/cloud/openai_tts_provider.dart';
import 'package:tayi_whisper/services/tts/tts_provider.dart';

class _RecordingProvider implements TtsProvider {
  _RecordingProvider(this.onChunk);

  final Future<void> Function(String text, String outputPath) onChunk;

  @override
  Future<String> synthesizeChunk({
    required String text,
    required String outputPath,
  }) async {
    await onChunk(text, outputPath);
    await File(outputPath).writeAsBytes(const [1, 2, 3]);
    return outputPath;
  }

  @override
  Future<List<String>> synthesizeToFiles({
    required String text,
    required String outputDir,
    required String baseName,
  }) async =>
      ['$outputDir/${baseName}_0.mp3'];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CloudVoicePreviewService', () {
    late Box settingsBox;
    late SettingsRepository settings;

    setUp(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async {
          if (call.method == 'getTemporaryDirectory') {
            return Directory.systemTemp.path;
          }
          return null;
        },
      );
      Hive.init('./.dart_tool/test_voice_preview_hive');
      settingsBox = await Hive.openBox('settings_voice_preview_test');
      await settingsBox.clear();
      settings = SettingsRepository.instance;
      settings.init(box: settingsBox);
      await settings.setTtsEngine(TtsEngine.cloud);
      await settings.setOpenaiApiKey('sk-test');
      await settings.setVoiceForCloudProvider(CloudTtsProvider.openai, 'marin');
      await settings.setCloudNarrationStyle(CloudNarrationStyle.audiobook);
    });

    tearDown(() async {
      await settingsBox.clear();
      await settingsBox.close();
    });

    test('synthétise un extrait via le provider courant', () async {
      String? capturedText;
      String? playedPath;
      final service = CloudVoicePreviewService(
        settings: settings,
        playPreviewFile: (path) async {
          playedPath = path;
        },
        providerFactory: ({
          required CloudTtsProvider provider,
          required String apiKey,
          required String voice,
          required CloudNarrationStyle narrationStyle,
        }) {
          expect(provider, CloudTtsProvider.openai);
          expect(apiKey, 'sk-test');
          expect(voice, 'marin');
          expect(narrationStyle, CloudNarrationStyle.audiobook);
          return _RecordingProvider((text, _) async {
            capturedText = text;
          });
        },
      );

      try {
        await service.previewVoice(
          provider: CloudTtsProvider.openai,
          voice: 'marin',
          narrationStyle: CloudNarrationStyle.audiobook,
        );
      } finally {
        await service.dispose();
      }

      expect(
        capturedText,
        'This is a sample of the selected voice for your audiobook.',
      );
      expect(playedPath, isNotNull);
      expect(File(playedPath!).existsSync(), isFalse);
    });
  });

  group('OpenAiTtsProvider', () {
    test('envoie instructions et voix au modèle mini-tts', () async {
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response.bytes(const [9, 8, 7], 200);
      });

      final provider = OpenAiTtsProvider(
        apiKey: 'sk-test',
        voice: 'marin',
        narrationStyle: CloudNarrationStyle.audiobook,
        client: client,
      );

      final output = File(
        '${Directory.systemTemp.path}/openai_tts_test_${DateTime.now().millisecondsSinceEpoch}.mp3',
      );
      await provider.synthesizeChunk(text: 'Hello world', outputPath: output.path);

      expect(capturedBody?['model'], 'gpt-4o-mini-tts');
      expect(capturedBody?['voice'], 'marin');
      expect(capturedBody?['input'], 'Hello world');
      expect(capturedBody?['instructions'], isNotEmpty);
      expect(await output.readAsBytes(), const [9, 8, 7]);

      if (output.existsSync()) {
        await output.delete();
      }
    });
  });
}
