import '../data/repositories/settings_repository.dart';

class CloudVoiceOption {
  const CloudVoiceOption({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}

const openAiVoiceOptions = <CloudVoiceOption>[
  CloudVoiceOption(id: 'marin', label: 'Marin'),
  CloudVoiceOption(id: 'cedar', label: 'Cedar'),
  CloudVoiceOption(id: 'coral', label: 'Coral'),
  CloudVoiceOption(id: 'nova', label: 'Nova'),
  CloudVoiceOption(id: 'alloy', label: 'Alloy'),
  CloudVoiceOption(id: 'shimmer', label: 'Shimmer'),
  CloudVoiceOption(id: 'echo', label: 'Echo'),
  CloudVoiceOption(id: 'fable', label: 'Fable'),
];

const geminiVoiceOptions = <CloudVoiceOption>[
  CloudVoiceOption(id: 'Kore', label: 'Kore — Firm'),
  CloudVoiceOption(id: 'Charon', label: 'Charon — Informative'),
  CloudVoiceOption(id: 'Aoede', label: 'Aoede — Breezy'),
  CloudVoiceOption(id: 'Sulafat', label: 'Sulafat — Warm'),
  CloudVoiceOption(id: 'Vindemiatrix', label: 'Vindemiatrix — Gentle'),
  CloudVoiceOption(id: 'Gacrux', label: 'Gacrux — Mature'),
  CloudVoiceOption(id: 'Puck', label: 'Puck — Upbeat'),
  CloudVoiceOption(id: 'Leda', label: 'Leda — Youthful'),
];

const defaultOpenAiVoiceId = 'marin';
const defaultGeminiVoiceId = 'Kore';

List<CloudVoiceOption> voiceOptionsFor(CloudTtsProvider provider) {
  switch (provider) {
    case CloudTtsProvider.gemini:
      return geminiVoiceOptions;
    case CloudTtsProvider.openai:
      return openAiVoiceOptions;
  }
}

String defaultVoiceFor(CloudTtsProvider provider) {
  switch (provider) {
    case CloudTtsProvider.gemini:
      return defaultGeminiVoiceId;
    case CloudTtsProvider.openai:
      return defaultOpenAiVoiceId;
  }
}

String normalizeVoiceId(CloudTtsProvider provider, String? value) {
  final fallback = defaultVoiceFor(provider);
  if (value == null || value.trim().isEmpty) return fallback;
  final id = value.trim();
  final known = voiceOptionsFor(provider).any((option) => option.id == id);
  return known ? id : fallback;
}
