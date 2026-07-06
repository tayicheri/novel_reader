class NovelExtractionException implements Exception {
  NovelExtractionException(this.message);

  final String message;

  @override
  String toString() => message;
}
