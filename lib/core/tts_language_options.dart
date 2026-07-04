class TtsLanguageOption {
  const TtsLanguageOption({
    required this.code,
    required this.label,
  });

  final String code;
  final String label;
}

/// Langues proposées pour le TTS natif (codes BCP-47).
const ttsLanguageOptions = <TtsLanguageOption>[
  TtsLanguageOption(code: 'en-US', label: 'English (US)'),
  TtsLanguageOption(code: 'en-GB', label: 'English (UK)'),
  TtsLanguageOption(code: 'fr-FR', label: 'Français'),
  TtsLanguageOption(code: 'es-ES', label: 'Español'),
  TtsLanguageOption(code: 'de-DE', label: 'Deutsch'),
  TtsLanguageOption(code: 'it-IT', label: 'Italiano'),
  TtsLanguageOption(code: 'pt-BR', label: 'Português (Brasil)'),
];

const defaultTtsLanguageCode = 'en-US';

String normalizeTtsLanguageCode(String? value) {
  if (value == null || value.trim().isEmpty) {
    return defaultTtsLanguageCode;
  }
  final code = value.trim();
  final known = ttsLanguageOptions.any((option) => option.code == code);
  return known ? code : defaultTtsLanguageCode;
}

TtsLanguageOption ttsLanguageOptionFor(String code) {
  return ttsLanguageOptions.firstWhere(
    (option) => option.code == code,
    orElse: () => ttsLanguageOptions.first,
  );
}
