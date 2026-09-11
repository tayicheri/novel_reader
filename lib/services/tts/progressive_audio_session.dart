import 'dart:async';
import 'dart:io';

import '../../core/cloud_narration_styles.dart';
import '../../data/repositories/settings_repository.dart';
import 'chapter_audio_progress.dart';
import 'text_chunker.dart';
import 'tts_provider.dart';

/// Synthèse audio segment par segment pour démarrer la lecture rapidement.
class ProgressiveAudioSession {
  ProgressiveAudioSession({
    required this.sourceUrl,
    required this.engine,
    required this.outputDir,
    required this.baseName,
    required this.chunks,
    required this.provider,
    required this.segmentExtension,
    this.cloudProvider,
    this.cloudVoice,
    this.narrationStyle,
  });

  final String sourceUrl;
  final TtsEngine engine;
  final CloudTtsProvider? cloudProvider;
  final String? cloudVoice;
  final CloudNarrationStyle? narrationStyle;
  final String outputDir;
  final String baseName;
  final List<String> chunks;
  final TtsProvider provider;
  final String segmentExtension;

  int _nextIndex = 0;
  final List<String> _paths = [];
  Future<void> _gate = Future.value();

  int get totalChunks => chunks.length;
  int get completedChunks => _paths.length;
  bool get isComplete => _nextIndex >= chunks.length;
  List<String> get segmentPaths => List.unmodifiable(_paths);

  double get synthesizedTextFraction =>
      ChapterAudioProgress.synthesizedTextFraction(
        chunks: chunks,
        completedChunks: completedChunks,
      );

  Future<T> _locked<T>(Future<T> Function() run) {
    final previous = _gate;
    final done = Completer<void>();
    _gate = done.future;
    return previous.then((_) => run()).whenComplete(done.complete);
  }

  /// Returns the first synthesized segment, synthesizing it if needed.
  Future<String?> firstSegmentPath() {
    return _locked(() async {
      if (_paths.isNotEmpty) return _paths.first;
      return _synthesizeUnlocked();
    });
  }

  /// Synthétise le prochain segment. Retourne `null` si tout est terminé.
  Future<String?> synthesizeNext() {
    return _locked(_synthesizeUnlocked);
  }

  Future<String?> _synthesizeUnlocked() async {
    if (isComplete) return null;

    final index = _nextIndex++;
    final path = '$outputDir/${baseName}_$index.$segmentExtension';
    await provider.synthesizeChunk(text: chunks[index], outputPath: path);
    _paths.add(path);
    return path;
  }
}

String segmentExtensionFor(
  TtsEngine engine, {
  CloudTtsProvider? cloudProvider,
}) {
  if (engine == TtsEngine.kokoro) return 'wav';
  if (engine == TtsEngine.cloud) {
    if (cloudProvider == CloudTtsProvider.gemini) return 'wav';
    return 'mp3';
  }
  if (Platform.isIOS || Platform.isMacOS) return 'caf';
  return 'wav';
}

List<String> splitTextChunks(
  String text, {
  TtsEngine engine = TtsEngine.native,
}) {
  final chunks = engine == TtsEngine.kokoro
      ? TextChunker.splitForKokoro(text)
      : TextChunker.split(text);
  if (chunks.isEmpty) {
    throw TtsSynthesisException('Texte vide pour la synthèse audio.');
  }
  return chunks;
}
