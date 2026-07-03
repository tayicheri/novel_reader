import 'package:hive/hive.dart';

class FavoriteWork {
  FavoriteWork({
    required this.id,
    required this.title,
    required this.lastUrl,
    this.scrollOffset = 0,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String title;
  final String lastUrl;
  final double scrollOffset;
  final DateTime updatedAt;

  FavoriteWork copyWith({
    String? title,
    String? lastUrl,
    double? scrollOffset,
    DateTime? updatedAt,
  }) {
    return FavoriteWork(
      id: id,
      title: title ?? this.title,
      lastUrl: lastUrl ?? this.lastUrl,
      scrollOffset: scrollOffset ?? this.scrollOffset,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class FavoriteWorkAdapter extends TypeAdapter<FavoriteWork> {
  @override
  final int typeId = 0;

  @override
  FavoriteWork read(BinaryReader reader) {
    final id = reader.readString();
    final title = reader.readString();
    final lastUrl = reader.readString();
    final scrollOffset = reader.readDouble();
    final updatedAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    return FavoriteWork(
      id: id,
      title: title,
      lastUrl: lastUrl,
      scrollOffset: scrollOffset,
      updatedAt: updatedAt,
    );
  }

  @override
  void write(BinaryWriter writer, FavoriteWork obj) {
    writer
      ..writeString(obj.id)
      ..writeString(obj.title)
      ..writeString(obj.lastUrl)
      ..writeDouble(obj.scrollOffset)
      ..writeInt(obj.updatedAt.millisecondsSinceEpoch);
  }
}
