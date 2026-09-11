import 'dart:typed_data';

/// Encode raw PCM as a 44-byte RIFF/WAVE file.
Uint8List pcmToWav(
  Uint8List pcm, {
  required int sampleRate,
  int channels = 1,
  int bitsPerSample = 16,
}) {
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  final blockAlign = channels * bitsPerSample ~/ 8;
  final dataSize = pcm.length;
  final header = ByteData(44)
    ..setUint8(0, 0x52) // RIFF
    ..setUint8(1, 0x49)
    ..setUint8(2, 0x46)
    ..setUint8(3, 0x46)
    ..setUint8(8, 0x57) // WAVE
    ..setUint8(9, 0x41)
    ..setUint8(10, 0x56)
    ..setUint8(11, 0x45)
    ..setUint8(12, 0x66) // fmt
    ..setUint8(13, 0x6d)
    ..setUint8(14, 0x74)
    ..setUint8(15, 0x20)
    ..setUint8(36, 0x64) // data
    ..setUint8(37, 0x61)
    ..setUint8(38, 0x74)
    ..setUint8(39, 0x61)
    ..setUint32(4, 36 + dataSize, Endian.little)
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, channels, Endian.little)
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, byteRate, Endian.little)
    ..setUint16(32, blockAlign, Endian.little)
    ..setUint16(34, bitsPerSample, Endian.little)
    ..setUint32(40, dataSize, Endian.little);

  final wav = Uint8List(44 + dataSize);
  wav.setRange(0, 44, header.buffer.asUint8List());
  wav.setRange(44, 44 + dataSize, pcm);
  return wav;
}

/// Convert Float32 PCM (-1..1) to 16-bit little-endian PCM.
Uint8List float32ToInt16Pcm(List<double> samples) {
  final bytes = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    final clamped = samples[i].clamp(-1.0, 1.0);
    final int16 = (clamped * 32767).round();
    bytes.setInt16(i * 2, int16, Endian.little);
  }
  return bytes.buffer.asUint8List();
}

Uint8List float32ToWav(
  List<double> samples, {
  required int sampleRate,
  int channels = 1,
}) {
  return pcmToWav(
    float32ToInt16Pcm(samples),
    sampleRate: sampleRate,
    channels: channels,
  );
}
