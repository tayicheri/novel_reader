import 'package:flutter_test/flutter_test.dart';

import 'package:tayi_whisper/core/kokoro_voice_options.dart';
import 'package:tayi_whisper/services/tts/text_chunker.dart';

void main() {
  group('TextChunker', () {
    test('respecte une limite courte pour un paragraphe trop long', () {
      final text = List.generate(12, (i) => 'Phrase numéro $i du roman.').join(' ');
      final chunks = TextChunker.split(text, maxChunkLength: 40);
      expect(chunks, isNotEmpty);
      expect(chunks.every((chunk) => chunk.length <= 40), isTrue);
    });

    test('garde le défaut 3500 pour le TTS cloud/natif', () {
      final text = 'Paragraphe un.\n\nParagraphe deux.';
      expect(TextChunker.split(text), ['Paragraphe un.\n\nParagraphe deux.']);
    });

    test('Kokoro coupe à chaque ponctuation suivie d\'un blanc', () {
      expect(
        TextChunker.splitForKokoro(
          'Hello, world. Next sentence! Last? End',
        ),
        ['Hello,', 'world.', 'Next sentence!', 'Last?', 'End'],
      );
    });

    test('Kokoro garde le dernier fragment sans blanc après la ponctuation', () {
      expect(
        TextChunker.splitForKokoro('Bonjour, tout le monde.'),
        ['Bonjour,', 'tout le monde.'],
      );
    });

    test('Kokoro recoupe une clause trop longue sans ponctuation', () {
      final text = List.filled(80, 'mot').join(' ');
      final chunks = TextChunker.splitForKokoro(text);
      expect(chunks, isNotEmpty);
      expect(
        chunks.every(
          (chunk) => chunk.length <= TextChunker.kokoroMaxChunkLength,
        ),
        isTrue,
      );
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
