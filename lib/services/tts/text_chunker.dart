class TextChunker {
  static const int maxChunkLength = 3500;

  static List<String> split(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return [];

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

      if (part.length > maxChunkLength) {
        flush();
        var start = 0;
        while (start < part.length) {
          final end = (start + maxChunkLength).clamp(0, part.length);
          chunks.add(part.substring(start, end));
          start = end;
        }
        continue;
      }

      final candidate = buffer.isEmpty ? part : '${buffer.toString()}\n\n$part';
      if (candidate.length > maxChunkLength) {
        flush();
        buffer.write(part);
      } else {
        buffer.write(buffer.isEmpty ? part : '\n\n$part');
      }
    }

    flush();
    return chunks;
  }
}
