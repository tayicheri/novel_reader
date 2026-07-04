import '../data/repositories/settings_repository.dart';

class CloudTtsProviderOption {
  const CloudTtsProviderOption({
    required this.provider,
    required this.label,
  });

  final CloudTtsProvider provider;
  final String label;
}

const cloudTtsProviderOptions = <CloudTtsProviderOption>[
  CloudTtsProviderOption(provider: CloudTtsProvider.gemini, label: 'Google Gemini'),
  CloudTtsProviderOption(provider: CloudTtsProvider.openai, label: 'OpenAI'),
];
