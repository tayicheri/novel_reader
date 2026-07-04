import 'package:flutter/material.dart';

import '../../core/cloud_tts_options.dart';
import '../../core/tts_language_options.dart';
import '../../data/repositories/settings_repository.dart';
import 'cloud_tts_settings_section.dart';

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

  @override
  void initState() {
    super.initState();
    _ttsEngine = _settings.ttsEngine;
    _cloudTtsProvider = _settings.cloudTtsProvider;
    _ttsLanguage = _settings.ttsLanguage;
    _geminiApiKeyController.text = _settings.geminiApiKey ?? '';
    _openaiApiKeyController.text = _settings.openaiApiKey ?? '';
  }

  @override
  void dispose() {
    _geminiApiKeyController.dispose();
    _openaiApiKeyController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCloud = _ttsEngine == TtsEngine.cloud;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Réglages'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Synthèse vocale',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SegmentedButton<TtsEngine>(
            segments: const [
              ButtonSegment(
                value: TtsEngine.native,
                label: Text('TTS natif'),
              ),
              ButtonSegment(
                value: TtsEngine.cloud,
                label: Text('TTS cloud'),
              ),
            ],
            selected: {_ttsEngine},
            onSelectionChanged: (selection) => _saveTtsEngine(selection.first),
          ),
          const SizedBox(height: 12),
          Text(
            isCloud
                ? 'Sans connexion, la synthèse cloud peut échouer — repassez en TTS natif si besoin.'
                : 'TTS natif : fonctionne hors-ligne.',
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
            isCloud
                ? 'TTS cloud : la langue suit le texte. Ce réglage s’applique au TTS natif (hors-ligne).'
                : 'Utilisée pour la synthèse vocale native.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
