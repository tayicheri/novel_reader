import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/hive_boxes.dart';

class SettingsRepository {
  SettingsRepository._();

  static final SettingsRepository instance = SettingsRepository._();

  static const String _isDarkModeKey = 'isDarkMode';

  Box? _box;
  final ValueNotifier<bool> isDarkMode = ValueNotifier(false);

  void init({Box? box}) {
    _box = box;
    isDarkMode.value = _readDarkMode();
  }

  Box get box {
    final resolved = _box ?? Hive.box(HiveBoxes.settings);
    _box ??= resolved;
    return resolved;
  }

  bool _readDarkMode() {
    final value = box.get(_isDarkModeKey);
    return value is bool ? value : false;
  }

  Future<void> setDarkMode(bool value) async {
    await box.put(_isDarkModeKey, value);
    isDarkMode.value = value;
  }
}
