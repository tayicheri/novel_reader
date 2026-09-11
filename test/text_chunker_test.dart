import 'package:flutter_test/flutter_test.dart';

import 'package:tayi_whisper/core/kokoro_voice_options.dart';
import 'package:tayi_whisper/services/tts/text_chunker.dart';

void main() {
  group('TextChunker', () {
    test('respecte une limite courte pour Kokoro', () {
      final text = List.generate(12, (i) => 'Phrase numéro $i du roman.').join(' ');
      final chunks = TextChunker.split(text, maxChunkLength: 40);
      expect(chunks, isNotEmpty);
      expect(chunks.every((chunk) => chunk.length <= 40), isTrue);
    });

    test('garde le défaut 3500 pour le TTS cloud/natif', () {
      final text = 'Paragraphe un.\n\nParagraphe deux.';
      expect(TextChunker.split(text), ['Paragraphe un.\n\nParagraphe deux.']);
    });
  });

  group('Kokoro voices', () {
    test('filtre le français vers ff_siwis', () {
      expect(defaultKokoroVoiceFor('fr-FR'), 'ff_siwis');
      expect(normalizeKokoroVoiceId('fr-FR', null), 'ff_siwis');
      expect(kokoroHasNativeVoices('de-DE'), isFalse);
      expect(kokoroPhonemeLanguage('fr-FR'), 'fr-fr');
    });
  });
}
