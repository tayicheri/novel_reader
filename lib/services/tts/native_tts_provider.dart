import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';

import 'text_chunker.dart';
import 'tts_provider.dart';

class NativeTtsProvider implements TtsProvider {
  NativeTtsProvider({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    // awaitSpeakCompletion(true) before synthesizeToFile crashes iOS (flutter_tts #290).
    if (Platform.isIOS || Platform.isAndroid) {
      await _tts.awaitSynthCompletion(true);
    }
    _configured = true;
  }

  @override
  Future<String> synthesizeChunk({
    required String text,
    required String outputPath,
  }) async {
    await _ensureConfigured();
    final result = await _tts.synthesizeToFile(text, outputPath, true);
    if (result == null) {
      throw TtsSynthesisException('Échec de la synthèse native.');
    }
    return outputPath;
  }

  @override
  Future<List<String>> synthesizeToFiles({
    required String text,
    required String outputDir,
    required String baseName,
  }) async {
    final chunks = TextChunker.split(text);
    if (chunks.isEmpty) {
      throw TtsSynthesisException('Texte vide pour la synthèse audio.');
    }

    final paths = <String>[];
    final ext = Platform.isIOS || Platform.isMacOS ? 'caf' : 'wav';
    for (var i = 0; i < chunks.length; i++) {
      final path = '$outputDir/${baseName}_$i.$ext';
      await synthesizeChunk(text: chunks[i], outputPath: path);
      paths.add(path);
    }
    return paths;
  }
}
