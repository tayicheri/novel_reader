abstract class TtsProvider {
  Future<List<String>> synthesizeToFiles({
    required String text,
    required String outputDir,
    required String baseName,
  });

  /// Synthétise un seul segment de texte vers [outputPath].
  Future<String> synthesizeChunk({
    required String text,
    required String outputPath,
  });
}

class TtsSynthesisException implements Exception {
  TtsSynthesisException(this.message);

  final String message;

  @override
  String toString() => message;
}
