import 'package:flutter/material.dart';

import '../../core/cloud_narration_styles.dart';
import '../../core/cloud_voice_options.dart';
import '../../data/repositories/settings_repository.dart';
import '../../services/tts/cloud/cloud_voice_preview_service.dart';
import '../../services/tts/tts_provider.dart';

class CloudTtsSettingsSection extends StatefulWidget {
  const CloudTtsSettingsSection({
    super.key,
    required this.provider,
    required this.hasApiKey,
  });

  final CloudTtsProvider provider;
  final bool hasApiKey;

  @override
  State<CloudTtsSettingsSection> createState() => _CloudTtsSettingsSectionState();
}

class _CloudTtsSettingsSectionState extends State<CloudTtsSettingsSection> {
  final _settings = SettingsRepository.instance;
  final _previewService = CloudVoicePreviewService();

  late CloudNarrationStyle _narrationStyle;
  late String _voiceId;
  bool _previewing = false;

  @override
  void initState() {
    super.initState();
    _loadFromSettings();
  }

  @override
  void didUpdateWidget(covariant CloudTtsSettingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider != widget.provider) {
      _loadFromSettings();
    }
  }

  void _loadFromSettings() {
    _narrationStyle = _settings.cloudNarrationStyle;
    _voiceId = _settings.voiceForCloudProvider(widget.provider);
  }

  @override
  void dispose() {
    _previewService.dispose();
    super.dispose();
  }

  Future<void> _saveNarrationStyle(CloudNarrationStyle style) async {
    await _settings.setCloudNarrationStyle(style);
    setState(() => _narrationStyle = style);
  }

  Future<void> _saveVoice(String? voiceId) async {
    if (voiceId == null) return;
    await _settings.setVoiceForCloudProvider(widget.provider, voiceId);
    setState(() => _voiceId = voiceId);
  }

  Future<void> _previewVoice() async {
    if (!widget.hasApiKey || _previewing) return;

    setState(() => _previewing = true);
    try {
      await _previewService.previewVoice(
        provider: widget.provider,
        voice: _voiceId,
        narrationStyle: _narrationStyle,
      );
    } on TtsSynthesisException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Échec du test de voix.')),
      );
    } finally {
      if (mounted) {
        setState(() => _previewing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final voiceOptions = voiceOptionsFor(widget.provider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Style de narration',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SegmentedButton<CloudNarrationStyle>(
          segments: [
            for (final option in cloudNarrationStyleOptions)
              ButtonSegment(
                value: option.style,
                label: Text(option.label),
              ),
          ],
          selected: {_narrationStyle},
          onSelectionChanged: (selection) =>
              _saveNarrationStyle(selection.first),
        ),
        const SizedBox(height: 24),
        Text(
          'Voix',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey('${widget.provider.name}_$_voiceId'),
          initialValue: _voiceId,
          decoration: const InputDecoration(
            labelText: 'Voix cloud',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final option in voiceOptions)
              DropdownMenuItem(
                value: option.id,
                child: Text(option.label),
              ),
          ],
          onChanged: _saveVoice,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: widget.hasApiKey && !_previewing ? _previewVoice : null,
          icon: _previewing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow),
          label: const Text('Tester la voix'),
        ),
        const SizedBox(height: 8),
        Text(
          'Changer de voix ou de style : utilisez le bouton ↻ du lecteur pour régénérer l\'audio.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
