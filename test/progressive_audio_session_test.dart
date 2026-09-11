import 'package:flutter_test/flutter_test.dart';

import 'package:tayi_whisper/data/repositories/settings_repository.dart';
import 'package:tayi_whisper/services/tts/progressive_audio_session.dart';
import 'package:tayi_whisper/services/tts/tts_provider.dart';

class _RecordingProvider implements TtsProvider {
  int calls = 0;

  @override
  Future<String> synthesizeChunk({
    required String text,
    required String outputPath,
  }) async {
    calls++;
    return outputPath;
  }

  @override
  Future<List<String>> synthesizeToFiles({
    required String text,
    required String outputDir,
    required String baseName,
  }) async =>
      [];
}

void main() {
  test('firstSegmentPath ne resynthétise pas un segment déjà prêt', () async {
    final provider = _RecordingProvider();
    final session = ProgressiveAudioSession(
      sourceUrl: 'https://exemple.com/ch',
      engine: TtsEngine.native,
      outputDir: '/tmp',
      baseName: 'ch',
      chunks: ['un', 'deux'],
      provider: provider,
      segmentExtension: 'wav',
    );

    final first = await session.firstSegmentPath();
    final again = await session.firstSegmentPath();

    expect(first, '/tmp/ch_0.wav');
    expect(again, '/tmp/ch_0.wav');
    expect(provider.calls, 1);
    expect(session.completedChunks, 1);

    final second = await session.synthesizeNext();
    expect(second, '/tmp/ch_1.wav');
    expect(provider.calls, 2);
  });
}
