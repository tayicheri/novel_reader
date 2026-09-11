import 'package:flutter_test/flutter_test.dart';

import 'package:tayi_whisper/services/tts/chapter_audio_progress.dart';

void main() {
  group('ChapterAudioProgress', () {
    test('estime la durée avec un débit lambda de 14 car/s', () {
      expect(
        ChapterAudioProgress.estimateDuration('abcdefghijklmn'),
        const Duration(seconds: 1),
      );
    });

    test('mesure le texte déjà TTS au poids des chunks', () {
      expect(
        ChapterAudioProgress.synthesizedTextFraction(
          chunks: ['aa', 'bbbb', 'cc'],
          completedChunks: 1,
        ),
        2 / 8,
      );
      expect(
        ChapterAudioProgress.synthesizedTextFraction(
          chunks: ['aa', 'bbbb', 'cc'],
          completedChunks: 3,
        ),
        1.0,
      );
    });

    test('cumule la position dans la playlist', () {
      expect(
        ChapterAudioProgress.playlistPosition(
          currentIndex: 2,
          itemDurations: const [
            Duration(seconds: 3),
            Duration(seconds: 4),
            Duration(seconds: 5),
          ],
          itemPosition: const Duration(seconds: 1),
        ),
        const Duration(seconds: 8),
      );
    });

    test('mappe un seek chapitre vers l\'index du segment', () {
      final mapped = ChapterAudioProgress.mapPlaylistSeek(
        requested: const Duration(seconds: 5),
        itemDurations: const [
          Duration(seconds: 3),
          Duration(seconds: 4),
          Duration(seconds: 5),
        ],
      );
      expect(mapped.index, 1);
      expect(mapped.position, const Duration(seconds: 2));
    });
  });
}
