import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';

import 'text_chunker.dart';
import 'tts_provider.dart';

class NativeTtsProvider implements TtsProvider {
  NativeTtsProvider({
    FlutterTts? tts,
    String Function()? languageCode,
  })  : _tts = tts ?? FlutterTts(),
        _languageCode = languageCode ?? (() => 'en-US');

  final FlutterTts _tts;
  final String Function() _languageCode;
  bool _awaitSynthConfigured = false;
  String? _appliedLanguage;

  Future<void> _ensureConfigured() async {
    final language = _languageCode();
    if (_appliedLanguage != language) {
      await _tts.setLanguage(language);
      _appliedLanguage = language;
    }
    if (_awaitSynthConfigured) return;
    // awaitSpeakCompletion(true) before synthesizeToFile crashes iOS (flutter_tts #290).
    if (Platform.isIOS || Platform.isAndroid) {
      await _tts.awaitSynthCompletion(true);
    }
    _awaitSynthConfigured = true;
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
