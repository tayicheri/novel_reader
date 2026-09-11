import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/kokoro_voice_options.dart';
import '../../data/repositories/settings_repository.dart';
import '../../services/tts/kokoro/kokoro_model_store.dart';
import '../../services/tts/kokoro_tts_provider.dart';
import '../../services/tts/tts_provider.dart';

class KokoroTtsSettingsSection extends StatefulWidget {
  const KokoroTtsSettingsSection({super.key});

  @override
  State<KokoroTtsSettingsSection> createState() =>
      _KokoroTtsSettingsSectionState();
}

class _KokoroTtsSettingsSectionState extends State<KokoroTtsSettingsSection> {
  final _settings = SettingsRepository.instance;
  final _previewProvider = KokoroTtsProvider();
  late String _voiceId;
  bool _previewing = false;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _voiceId = _settings.kokoroVoice;
    KokoroModelStore.instance.progress.addListener(_onDownloadProgress);
  }

  @override
  void dispose() {
    KokoroModelStore.instance.progress.removeListener(_onDownloadProgress);
    super.dispose();
  }

  void _onDownloadProgress() {
    if (mounted) setState(() {});
  }

  Future<void> _saveVoice(String? voiceId) async {
    if (voiceId == null) return;
    await _settings.setKokoroVoice(voiceId);
    setState(() => _voiceId = voiceId);
  }

  Future<void> _ensureModel() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      await KokoroModelStore.instance.ensureReady();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Téléchargement Kokoro impossible : $error')),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _previewVoice() async {
    if (_previewing) return;
    setState(() => _previewing = true);
    File? tempFile;
    try {
      await KokoroModelStore.instance.ensureReady();
      final tempDir = await getTemporaryDirectory();
      tempFile = File('${tempDir.path}/kokoro_preview_$_voiceId.wav');
      if (tempFile.existsSync()) {
        await tempFile.delete();
      }
      await _previewProvider.synthesizeChunk(
        text: _previewSample(_settings.ttsLanguage),
        outputPath: tempFile.path,
      );
      final player = AudioPlayer();
      try {
        await player.setAudioSource(
          AudioSource.file(
            tempFile.path,
            tag: MediaItem(
              id: 'kokoro-preview-$_voiceId',
              title: 'Aperçu Kokoro',
              album: 'Tayi Whisper',
              artist: 'Tayi Whisper',
            ),
          ),
        );
        await player.play();
        await player.processingStateStream.firstWhere(
          (state) => state == ProcessingState.completed,
        );
      } finally {
        await player.dispose();
      }
    } on TtsSynthesisException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Échec du test de voix Kokoro.')),
      );
    } finally {
      if (tempFile != null && tempFile.existsSync()) {
        await tempFile.delete();
      }
      if (mounted) setState(() => _previewing = false);
    }
  }

  String _previewSample(String languageCode) {
    if (languageCode.startsWith('fr')) {
      return 'Bonjour, ceci est un aperçu de la voix Kokoro.';
    }
    if (languageCode.startsWith('es')) {
      return 'Hola, esta es una muestra de la voz Kokoro.';
    }
    if (languageCode.startsWith('it')) {
      return 'Ciao, questa è un\'anteprima della voce Kokoro.';
    }
    if (languageCode.startsWith('pt')) {
      return 'Olá, esta é uma prévia da voz Kokoro.';
    }
    return 'Hello, this is a preview of the Kokoro voice.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final language = _settings.ttsLanguage;
    final voices = kokoroVoicesForLanguage(language);
    final download = KokoroModelStore.instance.progress.value;
    final hasNativeVoices = kokoroHasNativeVoices(language);
    final selected = voices.any((option) => option.id == _voiceId)
        ? _voiceId
        : voices.first.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Voix Kokoro',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey('kokoro_$selected'),
          initialValue: selected,
          decoration: const InputDecoration(
            labelText: 'Voix on-device',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final option in voices)
              DropdownMenuItem(
                value: option.id,
                child: Text(option.label),
              ),
          ],
          onChanged: _saveVoice,
        ),
        if (!hasNativeVoices) ...[
          const SizedBox(height: 8),
          Text(
            'Kokoro n’a pas de voix allemande : repli sur l’anglais US.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (_downloading || download.status.isNotEmpty) ...[
          LinearProgressIndicator(value: download.progress == 0 ? null : download.progress),
          const SizedBox(height: 8),
          Text(
            download.status.isEmpty ? 'Préparation du modèle…' : download.status,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _downloading ? null : _ensureModel,
              icon: const Icon(Icons.download),
              label: const Text('Télécharger le modèle'),
            ),
            OutlinedButton.icon(
              onPressed: _previewing || _downloading ? null : _previewVoice,
              icon: _previewing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: const Text('Tester la voix'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Premier usage : téléchargement du modèle (~80 Mo). Ensuite, Kokoro fonctionne hors-ligne. Changez de voix : bouton ↻ du lecteur.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
