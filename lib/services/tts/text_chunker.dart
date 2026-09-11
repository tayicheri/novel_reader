class TextChunker {
  static const int maxChunkLength = 3500;
  static const int kokoroMaxChunkLength = 400;

  /// Coupe dès qu'une ponctuation est suivie d'un blanc, pour des inférences Kokoro courtes.
  static final _kokoroPunctuationBreak = RegExp(r'[.!?,;:…](?=\s)');

  static List<String> splitForKokoro(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return [];

    final chunks = <String>[];
    var start = 0;
    for (final match in _kokoroPunctuationBreak.allMatches(trimmed)) {
      final slice = trimmed.substring(start, match.end).trim();
      if (slice.isNotEmpty) {
        _appendBounded(slice, kokoroMaxChunkLength, chunks);
      }
      start = match.end;
    }
    final rest = trimmed.substring(start).trim();
    if (rest.isNotEmpty) {
      _appendBounded(rest, kokoroMaxChunkLength, chunks);
    }
    return chunks;
  }

  static List<String> split(
    String text, {
    int maxChunkLength = TextChunker.maxChunkLength,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return [];

    final limit = maxChunkLength < 1 ? TextChunker.maxChunkLength : maxChunkLength;
    final paragraphs = trimmed.split(RegExp(r'\n\s*\n'));
    final chunks = <String>[];
    var buffer = StringBuffer();

    void flush() {
      final value = buffer.toString().trim();
      if (value.isNotEmpty) {
        chunks.add(value);
      }
      buffer = StringBuffer();
    }

    for (final paragraph in paragraphs) {
      final part = paragraph.trim();
      if (part.isEmpty) continue;

      if (part.length > limit) {
        flush();
        _splitLongPart(part, limit, chunks);
        continue;
      }

      final candidate = buffer.isEmpty ? part : '${buffer.toString()}\n\n$part';
      if (candidate.length > limit) {
        flush();
        buffer.write(part);
      } else {
        buffer.write(buffer.isEmpty ? part : '\n\n$part');
      }
    }

    flush();
    return chunks;
  }

  static void _appendBounded(String part, int limit, List<String> chunks) {
    if (part.length <= limit) {
      chunks.add(part);
      return;
    }
    _splitLongPart(part, limit, chunks);
  }

  static void _splitLongPart(String part, int limit, List<String> chunks) {
    var start = 0;
    while (start < part.length) {
      var end = (start + limit).clamp(0, part.length);
      if (end < part.length) {
        final window = part.substring(start, end);
        final sentenceBreak = window.lastIndexOf(RegExp(r'[.!?…][\s]'));
        final spaceBreak = window.lastIndexOf(' ');
        if (sentenceBreak >= limit ~/ 2) {
          end = start + sentenceBreak + 1;
        } else if (spaceBreak >= limit ~/ 2) {
          end = start + spaceBreak;
        }
      }
      final slice = part.substring(start, end).trim();
      if (slice.isNotEmpty) {
        chunks.add(slice);
      }
      start = end;
    }
  }
}
