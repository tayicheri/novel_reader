import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';

import 'text_chunker.dart';
import 'tts_provider.dart';

class NativeTtsProvider implements TtsProvider {
  NativeTtsProvider({
    FlutterTts? tts,
    String Function()? languageCode,
    bool? isIOS,
    bool? isAndroid,
    bool? isMacOS,
  })  : _tts = tts ?? FlutterTts(),
        _languageCode = languageCode ?? (() => 'en-US'),
        _isIOS = isIOS ?? Platform.isIOS,
        _isAndroid = isAndroid ?? Platform.isAndroid,
        _isMacOS = isMacOS ?? Platform.isMacOS;

  final FlutterTts _tts;
  final String Function() _languageCode;
  final bool _isIOS;
  final bool _isAndroid;
  final bool _isMacOS;
  bool _awaitSynthConfigured = false;
  String? _appliedLanguage;
  Future<void>? _serialize;

  Future<void> _ensureConfigured() async {
    final language = _languageCode();
    if (_appliedLanguage != language) {
      await _tts.setLanguage(language);
      _appliedLanguage = language;
    }
    if (_awaitSynthConfigured) return;
    await _configureBackgroundAudio();
    // awaitSpeakCompletion(true) before synthesizeToFile crashes iOS (flutter_tts #290).
    if (_isIOS || _isAndroid) {
      await _tts.awaitSynthCompletion(true);
    }
    _awaitSynthConfigured = true;
  }

  /// Keeps native synthesis alive when the screen locks or the app is backgrounded.
  Future<void> _configureBackgroundAudio() async {
    if (_isIOS) {
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        const [IosTextToSpeechAudioCategoryOptions.mixWithOthers],
        IosTextToSpeechAudioMode.spokenAudio,
      );
      await _tts.autoStopSharedSession(false);
      return;
    }
    if (_isMacOS) {
      await _tts.autoStopSharedSession(false);
    }
  }

  @override
  Future<String> synthesizeChunk({
    required String text,
    required String outputPath,
  }) {
    final previous = _serialize ?? Future.value();
    final current = previous.then(
      (_) => _synthesizeChunk(text: text, outputPath: outputPath),
    );
    _serialize = current.then((_) {}, onError: (_) {});
    return current;
  }

  Future<String> _synthesizeChunk({
    required String text,
    required String outputPath,
  }) async {
    await _ensureConfigured();
    final result = await _tts.synthesizeToFile(text, outputPath, true);
    if (result == null ||
        result == 0 ||
        result == false ||
        !File(outputPath).existsSync()) {
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
