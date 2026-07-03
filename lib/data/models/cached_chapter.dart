import 'package:hive/hive.dart';

import '../../services/novel_extractor.dart';

class CachedChapter {
  CachedChapter({
    required this.sourceUrl,
    required this.title,
    required this.content,
    this.previousUrl,
    this.nextUrl,
    DateTime? cachedAt,
  }) : cachedAt = cachedAt ?? DateTime.now();

  final String sourceUrl;
  final String title;
  final String content;
  final String? previousUrl;
  final String? nextUrl;
  final DateTime cachedAt;

  factory CachedChapter.fromNovelChapter(NovelChapter chapter) {
    return CachedChapter(
      sourceUrl: chapter.sourceUrl,
      title: chapter.title,
      content: chapter.content,
      previousUrl: chapter.previousUrl,
      nextUrl: chapter.nextUrl,
    );
  }

  NovelChapter toNovelChapter() {
    return NovelChapter(
      title: title,
      content: content,
      sourceUrl: sourceUrl,
      previousUrl: previousUrl,
      nextUrl: nextUrl,
    );
  }
}

class CachedChapterAdapter extends TypeAdapter<CachedChapter> {
  @override
  final int typeId = 1;

  @override
  CachedChapter read(BinaryReader reader) {
    final sourceUrl = reader.readString();
    final title = reader.readString();
    final content = reader.readString();
    final hasPrevious = reader.readBool();
    final previousUrl = hasPrevious ? reader.readString() : null;
    final hasNext = reader.readBool();
    final nextUrl = hasNext ? reader.readString() : null;
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());

    return CachedChapter(
      sourceUrl: sourceUrl,
      title: title,
      content: content,
      previousUrl: previousUrl,
      nextUrl: nextUrl,
      cachedAt: cachedAt,
    );
  }

  @override
  void write(BinaryWriter writer, CachedChapter obj) {
    writer
      ..writeString(obj.sourceUrl)
      ..writeString(obj.title)
      ..writeString(obj.content)
      ..writeBool(obj.previousUrl != null);
    if (obj.previousUrl != null) {
      writer.writeString(obj.previousUrl!);
    }
    writer.writeBool(obj.nextUrl != null);
    if (obj.nextUrl != null) {
      writer.writeString(obj.nextUrl!);
    }
    writer.writeInt(obj.cachedAt.millisecondsSinceEpoch);
  }
}
