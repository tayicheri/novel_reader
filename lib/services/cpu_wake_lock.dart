import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the CPU awake while TTS is still catching up with playback.
class CpuWakeLock {
  Future<void> enable() => WakelockPlus.enable();

  Future<void> disable() => WakelockPlus.disable();
}
