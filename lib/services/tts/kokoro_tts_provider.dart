import 'dart:io';

import '../../data/repositories/settings_repository.dart';
import 'kokoro/kokoro_runtime.dart';
import 'text_chunker.dart';
import 'tts_provider.dart';
import 'wav_encoder.dart';

class KokoroTtsProvider implements TtsProvider {
  KokoroTtsProvider({
    SettingsRepository? settings,
    KokoroRuntime? runtime,
  })  : _settings = settings ?? SettingsRepository.instance,
        _runtime = runtime ?? OnDeviceKokoroRuntime();

  final SettingsRepository _settings;
  final KokoroRuntime _runtime;
  Future<void>? _serialize;

  @override
  Future<String> synthesizeChunk({
    required String text,
    required String outputPath,
  }) async {
    final previous = _serialize ?? Future.value();
    final current = previous.then((_) => _synthesizeChunk(text, outputPath));
    _serialize = current.then((_) {}, onError: (_) {});
    return current;
  }

  Future<String> _synthesizeChunk(String text, String outputPath) async {
    await _runtime.ensureReady();
    final samples = await _runtime.generate(
      text: text,
      voice: _settings.kokoroVoice,
      languageCode: _settings.ttsLanguage,
    );
    if (samples.isEmpty) {
      throw TtsSynthesisException('Réponse audio Kokoro vide.');
    }
    final wav = float32ToWav(samples, sampleRate: _runtime.sampleRate);
    await File(outputPath).writeAsBytes(wav);
    return outputPath;
  }

  @override
  Future<List<String>> synthesizeToFiles({
    required String text,
    required String outputDir,
    required String baseName,
  }) async {
    final chunks = TextChunker.splitForKokoro(text);
    if (chunks.isEmpty) {
      throw TtsSynthesisException('Texte vide pour la synthèse audio.');
    }

    final paths = <String>[];
    for (var i = 0; i < chunks.length; i++) {
      final path = '$outputDir/${baseName}_$i.wav';
      await synthesizeChunk(text: chunks[i], outputPath: path);
      paths.add(path);
    }
    return paths;
  }
}
