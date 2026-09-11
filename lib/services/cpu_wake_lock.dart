import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the CPU awake while on-device TTS is still catching up.
class CpuWakeLock {
  Future<void> enable() => WakelockPlus.enable();

  Future<void> disable() => WakelockPlus.disable();
}
