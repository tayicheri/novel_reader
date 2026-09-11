import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../../core/kokoro_voice_options.dart';

class KokoroDownloadProgress {
  const KokoroDownloadProgress({
    required this.status,
    this.progress = 0,
  });

  final String status;
  final double progress;

  static const idle = KokoroDownloadProgress(status: '');
}

class KokoroModelPaths {
  const KokoroModelPaths({
    required this.modelPath,
    required this.voicesDir,
  });

  final String modelPath;
  final String voicesDir;
}

/// Downloads and caches the on-device Kokoro ONNX model and voice packs.
class KokoroModelStore {
  KokoroModelStore({http.Client? client}) : _client = client ?? http.Client();

  static final KokoroModelStore instance = KokoroModelStore();

  static const modelFileName = 'model_quantized.onnx';
  static const modelUrl =
      'https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX/resolve/main/onnx/model_quantized.onnx';
  static const voicesBaseUrl =
      'https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX/resolve/main/voices';

  final http.Client _client;
  final ValueNotifier<KokoroDownloadProgress> progress =
      ValueNotifier(KokoroDownloadProgress.idle);

  Future<void>? _inFlight;

  Future<String> _rootDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/kokoro');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  Future<KokoroModelPaths> paths() async {
    final root = await _rootDir();
    return KokoroModelPaths(
      modelPath: '$root/$modelFileName',
      voicesDir: '$root/voices',
    );
  }

  String voicePath(String voicesDir, String voiceId) =>
      '$voicesDir/$voiceId.bin';

  Future<bool> get isReady async {
    final resolved = await paths();
    if (!File(resolved.modelPath).existsSync()) return false;
    for (final voice in kokoroVoiceOptions) {
      if (!File(voicePath(resolved.voicesDir, voice.id)).existsSync()) {
        return false;
      }
    }
    return true;
  }

  Future<KokoroModelPaths> ensureReady() async {
    final existing = _inFlight;
    if (existing != null) {
      await existing;
      return paths();
    }

    final future = _ensureReady();
    _inFlight = future;
    try {
      await future;
      return await paths();
    } finally {
      _inFlight = null;
    }
  }

  Future<void> _ensureReady() async {
    final resolved = await paths();
    final voicesDir = Directory(resolved.voicesDir);
    if (!voicesDir.existsSync()) {
      await voicesDir.create(recursive: true);
    }

    await _downloadIfNeeded(
      url: modelUrl,
      destPath: resolved.modelPath,
      label: 'Modèle Kokoro',
    );

    for (final voice in kokoroVoiceOptions) {
      await _downloadIfNeeded(
        url: '$voicesBaseUrl/${voice.id}.bin',
        destPath: voicePath(resolved.voicesDir, voice.id),
        label: 'Voix ${voice.label}',
      );
    }

    progress.value = const KokoroDownloadProgress(
      status: 'Prêt',
      progress: 1,
    );
  }

  Future<void> _downloadIfNeeded({
    required String url,
    required String destPath,
    required String label,
  }) async {
    final file = File(destPath);
    if (file.existsSync() && file.lengthSync() > 0) return;

    progress.value = KokoroDownloadProgress(
      status: 'Téléchargement : $label…',
      progress: 0,
    );

    final tmpPath = '$destPath.part';
    final tmpFile = File(tmpPath);
    if (tmpFile.existsSync()) {
      await tmpFile.delete();
    }

    final request = http.Request('GET', Uri.parse(url));
    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Échec du téléchargement Kokoro (code ${response.statusCode}).',
      );
    }

    final total = response.contentLength ?? 0;
    var received = 0;
    final sink = tmpFile.openWrite();
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        final ratio = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
        progress.value = KokoroDownloadProgress(
          status: 'Téléchargement : $label…',
          progress: ratio,
        );
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    if (file.existsSync()) {
      await file.delete();
    }
    await tmpFile.rename(destPath);
  }
}
