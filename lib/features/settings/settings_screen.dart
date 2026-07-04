import 'package:flutter/material.dart';

import '../../data/repositories/settings_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsRepository.instance;
  final _apiKeyController = TextEditingController();

  late TtsEngine _ttsEngine;

  @override
  void initState() {
    super.initState();
    _ttsEngine = _settings.ttsEngine;
    _apiKeyController.text = _settings.cloudTtsApiKey ?? '';
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveTtsEngine(TtsEngine engine) async {
    await _settings.setTtsEngine(engine);
    setState(() => _ttsEngine = engine);
  }

  Future<void> _saveApiKey() async {
    await _settings.setCloudTtsApiKey(_apiKeyController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Clé API enregistrée')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            'Hors-ligne : TTS natif automatiquement.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (_ttsEngine == TtsEngine.cloud) ...[
            const SizedBox(height: 24),
            TextField(
              controller: _apiKeyController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Clé API OpenAI',
                hintText: 'sk-...',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saveApiKey,
              child: const Text('Enregistrer la clé'),
            ),
          ],
        ],
      ),
    );
  }
}
