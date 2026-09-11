import 'package:flutter/material.dart';

import '../../core/cloud_tts_options.dart';
import '../../core/tts_language_options.dart';
import '../../data/repositories/settings_repository.dart';
import 'cloud_tts_settings_section.dart';
import 'kokoro_tts_settings_section.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsRepository.instance;
  final _geminiApiKeyController = TextEditingController();
  final _openaiApiKeyController = TextEditingController();

  late TtsEngine _ttsEngine;
  late CloudTtsProvider _cloudTtsProvider;
  late String _ttsLanguage;
  late ThemePreference _themePreference;

  @override
  void initState() {
    super.initState();
    _ttsEngine = _settings.ttsEngine;
    _cloudTtsProvider = _settings.cloudTtsProvider;
    _ttsLanguage = _settings.ttsLanguage;
    _themePreference = _settings.themePreference.value;
    _geminiApiKeyController.text = _settings.geminiApiKey ?? '';
    _openaiApiKeyController.text = _settings.openaiApiKey ?? '';
  }

  @override
  void dispose() {
    _geminiApiKeyController.dispose();
    _openaiApiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveTheme(ThemePreference preference) async {
    await _settings.setThemePreference(preference);
    setState(() => _themePreference = preference);
  }

  Future<void> _saveTtsEngine(TtsEngine engine) async {
    await _settings.setTtsEngine(engine);
    setState(() => _ttsEngine = engine);
  }

  Future<void> _saveCloudTtsProvider(CloudTtsProvider? provider) async {
    if (provider == null) return;
    await _settings.setCloudTtsProvider(provider);
    setState(() => _cloudTtsProvider = provider);
  }

  Future<void> _saveTtsLanguage(String? languageCode) async {
    if (languageCode == null) return;
    await _settings.setTtsLanguage(languageCode);
    setState(() => _ttsLanguage = languageCode);
  }

  Future<void> _saveGeminiApiKey() async {
    await _settings.setGeminiApiKey(_geminiApiKeyController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Clé API Gemini enregistrée')),
    );
  }

  Future<void> _saveOpenaiApiKey() async {
    await _settings.setOpenaiApiKey(_openaiApiKeyController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Clé API OpenAI enregistrée')),
    );
  }

  String _engineHint() {
    switch (_ttsEngine) {
      case TtsEngine.cloud:
        return 'Sans connexion, la synthèse cloud peut échouer — repassez en TTS natif ou Kokoro si besoin.';
      case TtsEngine.kokoro:
        return 'Kokoro : synthèse neuronale on-device. Premier usage : téléchargement du modèle.';
      case TtsEngine.native:
        return 'TTS natif : fonctionne hors-ligne.';
    }
  }

  String _languageHint() {
    switch (_ttsEngine) {
      case TtsEngine.cloud:
        return 'TTS cloud : la langue suit le texte. Ce réglage s’applique au TTS natif et à Kokoro.';
      case TtsEngine.kokoro:
        return 'Utilisée pour la phonémisation Kokoro et le filtrage des voix.';
      case TtsEngine.native:
        return 'Utilisée pour la synthèse vocale native.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCloud = _ttsEngine == TtsEngine.cloud;
    final isKokoro = _ttsEngine == TtsEngine.kokoro;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Réglages'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Apparence',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SegmentedButton<ThemePreference>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ThemePreference.system,
                label: Text('Système'),
                icon: Icon(Icons.brightness_auto),
              ),
              ButtonSegment(
                value: ThemePreference.light,
                label: Text('Clair'),
                icon: Icon(Icons.light_mode),
              ),
              ButtonSegment(
                value: ThemePreference.dark,
                label: Text('Sombre'),
                icon: Icon(Icons.dark_mode),
              ),
            ],
            selected: {_themePreference},
            onSelectionChanged: (selection) => _saveTheme(selection.first),
          ),
          const SizedBox(height: 32),
          Text(
            'Synthèse vocale',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SegmentedButton<TtsEngine>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: TtsEngine.native,
                label: Text('Natif'),
              ),
              ButtonSegment(
                value: TtsEngine.cloud,
                label: Text('Cloud'),
              ),
              ButtonSegment(
                value: TtsEngine.kokoro,
                label: Text('Kokoro'),
              ),
            ],
            selected: {_ttsEngine},
            onSelectionChanged: (selection) => _saveTtsEngine(selection.first),
          ),
          const SizedBox(height: 12),
          Text(
            _engineHint(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (isCloud) ...[
            const SizedBox(height: 24),
            Text(
              'Fournisseur cloud',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<CloudTtsProvider>(
              key: ValueKey(_cloudTtsProvider),
              initialValue: _cloudTtsProvider,
              decoration: const InputDecoration(
                labelText: 'API de synthèse',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final option in cloudTtsProviderOptions)
                  DropdownMenuItem(
                    value: option.provider,
                    child: Text(option.label),
                  ),
              ],
              onChanged: _saveCloudTtsProvider,
            ),
            const SizedBox(height: 16),
            if (_cloudTtsProvider == CloudTtsProvider.gemini) ...[
              TextField(
                controller: _geminiApiKeyController,
                obscureText: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Clé API Gemini',
                  hintText: 'AIza...',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saveGeminiApiKey,
                child: const Text('Enregistrer la clé Gemini'),
              ),
              const SizedBox(height: 24),
              CloudTtsSettingsSection(
                provider: CloudTtsProvider.gemini,
                hasApiKey: _geminiApiKeyController.text.trim().isNotEmpty ||
                    (_settings.geminiApiKey?.isNotEmpty ?? false),
              ),
            ] else ...[
              TextField(
                controller: _openaiApiKeyController,
                obscureText: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Clé API OpenAI',
                  hintText: 'sk-...',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saveOpenaiApiKey,
                child: const Text('Enregistrer la clé OpenAI'),
              ),
              const SizedBox(height: 24),
              CloudTtsSettingsSection(
                provider: CloudTtsProvider.openai,
                hasApiKey: _openaiApiKeyController.text.trim().isNotEmpty ||
                    (_settings.openaiApiKey?.isNotEmpty ?? false),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Changer de fournisseur : utilisez le bouton ↻ du lecteur pour régénérer l\'audio.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (isKokoro) ...[
            const SizedBox(height: 24),
            KokoroTtsSettingsSection(key: ValueKey(_ttsLanguage)),
          ],
          const SizedBox(height: 24),
          Text(
            'Langue de lecture',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey(_ttsLanguage),
            initialValue: _ttsLanguage,
            decoration: const InputDecoration(
              labelText: 'Langue TTS',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final option in ttsLanguageOptions)
                DropdownMenuItem(
                  value: option.code,
                  child: Text(option.label),
                ),
            ],
            onChanged: _saveTtsLanguage,
          ),
          const SizedBox(height: 8),
          Text(
            _languageHint(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
