import '../../../core/cloud_narration_styles.dart';

const cloudVoicePreviewSampleText =
    'This is a sample of the selected voice for your audiobook.';

class CloudNarrationPrompt {
  static String openAiInstructions(CloudNarrationStyle style) {
    switch (style) {
      case CloudNarrationStyle.audiobook:
        return 'Read as an immersive audiobook narrator. Warm tone, steady pace, '
            'natural pauses at paragraph breaks. Match emotional inflection to '
            'the story without overacting.';
      case CloudNarrationStyle.neutral:
        return 'Read clearly and naturally in a neutral tone. Steady pace, '
            'minimal dramatic emphasis.';
      case CloudNarrationStyle.dramatic:
        return 'Read with expressive audiobook delivery. Vary pace and emotion '
            'to match the tension and drama of the story.';
    }
  }

  static String geminiInput(String transcript, CloudNarrationStyle style) {
    final styleNote = switch (style) {
      CloudNarrationStyle.audiobook =>
        'Warm audiobook narrator for a novel. Natural pacing, immersive but not theatrical.',
      CloudNarrationStyle.neutral =>
        'Clear neutral reading voice. Steady pace with minimal dramatic emphasis.',
      CloudNarrationStyle.dramatic =>
        'Expressive storyteller with dynamic pacing and emotional emphasis.',
    };

    return '''
### DIRECTOR'S NOTES
Style: $styleNote
Pacing: Natural audiobook rhythm with subtle pauses between paragraphs.

#### TRANSCRIPT
$transcript''';
  }
}
