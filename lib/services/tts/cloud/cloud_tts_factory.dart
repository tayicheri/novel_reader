import '../../../core/cloud_narration_styles.dart';
import '../../../data/repositories/settings_repository.dart';
import '../tts_provider.dart';
import 'gemini_tts_provider.dart';
import 'openai_tts_provider.dart';

class CloudTtsFactory {
  static TtsProvider create({
    required CloudTtsProvider provider,
    required String apiKey,
    required String voice,
    required CloudNarrationStyle narrationStyle,
  }) {
    switch (provider) {
      case CloudTtsProvider.gemini:
        return GeminiTtsProvider(
          apiKey: apiKey,
          voice: voice,
          narrationStyle: narrationStyle,
        );
      case CloudTtsProvider.openai:
        return OpenAiTtsProvider(
          apiKey: apiKey,
          voice: voice,
          narrationStyle: narrationStyle,
        );
    }
  }
}
