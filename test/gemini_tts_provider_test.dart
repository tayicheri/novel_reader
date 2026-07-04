import 'package:flutter_test/flutter_test.dart';

import 'package:tayi_whisper/services/tts/cloud/gemini_tts_provider.dart';

void main() {
  group('GeminiTtsProvider audio extraction', () {
    test('lit audio depuis steps[].content[]', () {
      final block = GeminiTtsProvider.extractAudioBlockForTest({
        'status': 'completed',
        'steps': [
          {
            'content': [
              {
                'mime_type': 'audio/l16',
                'data': 'AQID',
              },
            ],
          },
        ],
      });

      expect(block?['data'], 'AQID');
      expect(block?['mime_type'], 'audio/l16');
    });

    test('préfère output_audio si présent', () {
      final block = GeminiTtsProvider.extractAudioBlockForTest({
        'output_audio': {
          'mime_type': 'audio/l16',
          'data': 'legacy',
        },
        'steps': [
          {
            'content': [
              {'mime_type': 'audio/l16', 'data': 'steps'},
            ],
          },
        ],
      });

      expect(block?['data'], 'legacy');
    });
  });
}
