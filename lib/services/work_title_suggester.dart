class WorkTitleSuggester {
  static final RegExp _chapterSuffix = RegExp(
    r'\s*[-–—|:]\s*(chapitre|chapter|ch\.?|ep\.?|episode|partie|part|vol\.?|volume|tome)\s*[\dIVXLC]+.*$',
    caseSensitive: false,
  );

  static final RegExp _leadingChapter = RegExp(
    r'^(chapitre|chapter|ch\.?|ep\.?|episode|partie|part|vol\.?|volume|tome)\s*[\dIVXLC]+\s*[-–—|:]?\s*',
    caseSensitive: false,
  );

  static final RegExp _trailingNumber = RegExp(
    r'\s*[-–—|:]\s*\d+\s*$',
  );

  String suggest({
    required String chapterTitle,
    String? sourceUrl,
  }) {
    var title = chapterTitle.trim();
    if (title.isEmpty) {
      return _fallbackFromUrl(sourceUrl);
    }

    title = title.replaceAll(_chapterSuffix, '');
    title = title.replaceAll(_leadingChapter, '');
    title = title.replaceAll(_trailingNumber, '');
    title = title.trim();

    if (title.isEmpty) {
      return _fallbackFromUrl(sourceUrl);
    }

    return title;
  }

  String _fallbackFromUrl(String? sourceUrl) {
    if (sourceUrl == null || sourceUrl.isEmpty) {
      return 'Œuvre sans titre';
    }

    final uri = Uri.tryParse(sourceUrl);
    if (uri == null || uri.host.isEmpty) {
      return 'Œuvre sans titre';
    }

    final host = uri.host.replaceFirst(RegExp(r'^www\.'), '');
    return host;
  }
}
