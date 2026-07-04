import 'package:hive_flutter/hive_flutter.dart';

import '../../core/hive_boxes.dart';
import '../../services/novel_extractor.dart';

class AudioProgressRepository {
  AudioProgressRepository._();

  static final AudioProgressRepository instance = AudioProgressRepository._();

  factory AudioProgressRepository.test() => AudioProgressRepository._();

  Box? _box;

  void init({Box? box}) {
    _box = box;
  }

  Box get box {
    final resolved = _box ?? Hive.box(HiveBoxes.audioProgress);
    _box ??= resolved;
    return resolved;
  }

  String _key(String rawUrl) => normalizeNovelUrl(rawUrl).toString();

  int getPosition(String rawUrl) {
    final value = box.get(_key(rawUrl));
    return value is int ? value : 0;
  }

  Future<void> savePosition(String rawUrl, int positionMs) async {
    await box.put(_key(rawUrl), positionMs);
  }

  Future<void> delete(String rawUrl) async {
    await box.delete(_key(rawUrl));
  }
}
