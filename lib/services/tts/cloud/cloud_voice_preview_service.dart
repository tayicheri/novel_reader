import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/cloud_narration_styles.dart';
import '../../../data/repositories/settings_repository.dart';
import '../tts_provider.dart';
import '../tts_synthesis_service.dart';
import 'cloud_narration_prompt.dart';
import 'cloud_tts_factory.dart';

typedef PreviewFilePlayer = Future<void> Function(String path);

Future<void> _defaultPreviewFilePlayer(String path) async {
  final player = AudioPlayer();
  try {
    await player.stop();
    await player.setFilePath(path);
    await player.play();
    await player.processingStateStream.firstWhere(
      (state) => state == ProcessingState.completed,
    );
  } finally {
    await player.dispose();
  }
}

class CloudVoicePreviewService {
  CloudVoicePreviewService({
    SettingsRepository? settings,
    CloudTtsProviderFactory? providerFactory,
    PreviewFilePlayer? playPreviewFile,
  })  : _settings = settings ?? SettingsRepository.instance,
        _providerFactory = providerFactory ?? CloudTtsFactory.create,
        _playPreviewFile = playPreviewFile ?? _defaultPreviewFilePlayer;

  final SettingsRepository _settings;
  final CloudTtsProviderFactory _providerFactory;
  final PreviewFilePlayer _playPreviewFile;
  bool _previewInFlight = false;

  bool get isPreviewing => _previewInFlight;

  Future<void> previewVoice({
    required CloudTtsProvider provider,
    required String voice,
    required CloudNarrationStyle narrationStyle,
  }) async {
    if (_previewInFlight) return;

    final apiKey = _settings.apiKeyForCloudProvider(provider);
    if (apiKey == null) {
      throw TtsSynthesisException('Clé API manquante pour le test de voix.');
    }

    _previewInFlight = true;
    File? tempFile;
    try {
      final ttsProvider = _providerFactory(
        provider: provider,
        apiKey: apiKey,
        voice: voice,
        narrationStyle: narrationStyle,
      );
      final extension = provider == CloudTtsProvider.gemini ? 'wav' : 'mp3';
      final tempDir = await getTemporaryDirectory();
      tempFile = File(
        '${tempDir.path}/voice_preview_${provider.name}_$voice.$extension',
      );
      if (tempFile.existsSync()) {
        await tempFile.delete();
      }

      await ttsProvider.synthesizeChunk(
        text: cloudVoicePreviewSampleText,
        outputPath: tempFile.path,
      );

      await _playPreviewFile(tempFile.path);
    } finally {
      _previewInFlight = false;
      if (tempFile != null && tempFile.existsSync()) {
        await tempFile.delete();
      }
    }
  }

  Future<void> dispose() async {}
}
