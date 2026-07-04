import 'dart:io';

import '../../data/repositories/settings_repository.dart';
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
  });

  final String sourceUrl;
  final TtsEngine engine;
  final String outputDir;
  final String baseName;
  final List<String> chunks;
  final TtsProvider provider;
  final String segmentExtension;

  int _nextIndex = 0;
  final List<String> _paths = [];

  int get totalChunks => chunks.length;
  int get completedChunks => _paths.length;
  bool get isComplete => _nextIndex >= chunks.length;
  List<String> get segmentPaths => List.unmodifiable(_paths);

  /// Synthétise le prochain segment. Retourne `null` si tout est terminé.
  Future<String?> synthesizeNext() async {
    if (isComplete) return null;

    final index = _nextIndex++;
    final path = '$outputDir/${baseName}_$index.$segmentExtension';
    await provider.synthesizeChunk(text: chunks[index], outputPath: path);
    _paths.add(path);
    return path;
  }
}

String segmentExtensionFor(TtsEngine engine) {
  if (engine == TtsEngine.cloud) return 'mp3';
  if (Platform.isIOS || Platform.isMacOS) return 'caf';
  return 'wav';
}

List<String> splitTextChunks(String text) {
  final chunks = TextChunker.split(text);
  if (chunks.isEmpty) {
    throw TtsSynthesisException('Texte vide pour la synthèse audio.');
  }
  return chunks;
}
