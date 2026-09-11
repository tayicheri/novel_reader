class KokoroVoiceOption {
  const KokoroVoiceOption({
    required this.id,
    required this.label,
    required this.languageCode,
  });

  final String id;
  final String label;
  final String languageCode;
}

const kokoroVoiceOptions = <KokoroVoiceOption>[
  KokoroVoiceOption(
    id: 'af_heart',
    label: 'Heart — US Female',
    languageCode: 'en-US',
  ),
  KokoroVoiceOption(
    id: 'af_bella',
    label: 'Bella — US Female',
    languageCode: 'en-US',
  ),
  KokoroVoiceOption(
    id: 'af_nicole',
    label: 'Nicole — US Female',
    languageCode: 'en-US',
  ),
  KokoroVoiceOption(
    id: 'am_adam',
    label: 'Adam — US Male',
    languageCode: 'en-US',
  ),
  KokoroVoiceOption(
    id: 'am_michael',
    label: 'Michael — US Male',
    languageCode: 'en-US',
  ),
  KokoroVoiceOption(
    id: 'bf_emma',
    label: 'Emma — UK Female',
    languageCode: 'en-GB',
  ),
  KokoroVoiceOption(
    id: 'bm_george',
    label: 'George — UK Male',
    languageCode: 'en-GB',
  ),
  KokoroVoiceOption(
    id: 'ff_siwis',
    label: 'Siwis — Française',
    languageCode: 'fr-FR',
  ),
  KokoroVoiceOption(
    id: 'ef_dora',
    label: 'Dora — Española',
    languageCode: 'es-ES',
  ),
  KokoroVoiceOption(
    id: 'if_sara',
    label: 'Sara — Italiana',
    languageCode: 'it-IT',
  ),
  KokoroVoiceOption(
    id: 'pf_dora',
    label: 'Dora — Português',
    languageCode: 'pt-BR',
  ),
];

const defaultKokoroVoiceId = 'af_heart';

const kokoroPhonemeLanguageForTts = <String, String>{
  'en-US': 'en-us',
  'en-GB': 'en-gb',
  'fr-FR': 'fr-fr',
  'es-ES': 'es',
  'it-IT': 'it',
  'pt-BR': 'pt-br',
  'de-DE': 'en-us',
};

List<KokoroVoiceOption> kokoroVoicesForLanguage(String languageCode) {
  final matching = kokoroVoiceOptions
      .where((option) => option.languageCode == languageCode)
      .toList();
  if (matching.isNotEmpty) return matching;
  return kokoroVoiceOptions
      .where((option) => option.languageCode == 'en-US')
      .toList();
}

String defaultKokoroVoiceFor(String languageCode) {
  return kokoroVoicesForLanguage(languageCode).first.id;
}

String normalizeKokoroVoiceId(String languageCode, String? value) {
  final options = kokoroVoicesForLanguage(languageCode);
  final fallback = options.first.id;
  if (value == null || value.trim().isEmpty) return fallback;
  final id = value.trim();
  final known = options.any((option) => option.id == id);
  return known ? id : fallback;
}

String kokoroPhonemeLanguage(String languageCode) {
  return kokoroPhonemeLanguageForTts[languageCode] ?? 'en-us';
}

bool kokoroHasNativeVoices(String languageCode) {
  return kokoroVoiceOptions.any((option) => option.languageCode == languageCode);
}
