import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/cloud_narration_styles.dart';
import '../text_chunker.dart';
import '../tts_provider.dart';
import '../wav_encoder.dart';
import 'cloud_narration_prompt.dart';

class GeminiTtsProvider implements TtsProvider {
  GeminiTtsProvider({
    required this.apiKey,
    required this.voice,
    required this.narrationStyle,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const _model = 'gemini-2.5-flash-preview-tts';

  final String apiKey;
  final String voice;
  final CloudNarrationStyle narrationStyle;
  final http.Client _client;

  @override
  Future<String> synthesizeChunk({
    required String text,
    required String outputPath,
  }) async {
    final input = CloudNarrationPrompt.geminiInput(text, narrationStyle);
    final response = await _client.post(
      Uri.parse('https://generativelanguage.googleapis.com/v1beta/interactions'),
      headers: {
        'x-goog-api-key': apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'input': input,
        'response_format': {'type': 'audio'},
        'generation_config': {
          'speech_config': [
            {'voice': voice},
          ],
        },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TtsSynthesisException(
        'Échec TTS Gemini (code ${response.statusCode}).',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final audioBlock = _extractAudioBlock(body);
    final data = audioBlock?['data'] as String?;
    final mimeType = audioBlock?['mime_type'] as String?;
    if (data == null || data.isEmpty) {
      throw TtsSynthesisException('Réponse audio Gemini vide.');
    }

    final pcm = base64Decode(data);
    final wavBytes = _toPlayableWav(pcm, mimeType: mimeType);
    await File(outputPath).writeAsBytes(wavBytes);
    return outputPath;
  }

  /// REST Interactions API returns audio in `steps[].content[]`, not `output_audio`.
  @visibleForTesting
  static Map<String, dynamic>? extractAudioBlockForTest(
    Map<String, dynamic> body,
  ) =>
      _extractAudioBlock(body);

  static Map<String, dynamic>? _extractAudioBlock(Map<String, dynamic> body) {
    final outputAudio = body['output_audio'];
    if (outputAudio is Map<String, dynamic>) {
      final data = outputAudio['data'];
      if (data is String && data.isNotEmpty) {
        return {
          'data': data,
          'mime_type': outputAudio['mime_type'],
        };
      }
    }

    final steps = body['steps'];
    if (steps is! List) return null;

    for (final step in steps) {
      if (step is! Map<String, dynamic>) continue;
      final content = step['content'];
      if (content is! List) continue;
      for (final block in content) {
        if (block is! Map<String, dynamic>) continue;
        final data = block['data'];
        final mimeType = block['mime_type'] as String?;
        if (data is String &&
            data.isNotEmpty &&
            (mimeType?.startsWith('audio/') ?? false)) {
          return {
            'data': data,
            'mime_type': mimeType,
          };
        }
      }
    }
    return null;
  }

  /// Gemini TTS returns raw PCM (`audio/l16`); wrap as WAV for playback.
  static Uint8List _toPlayableWav(Uint8List pcm, {String? mimeType}) {
    if (mimeType == 'audio/wav' || mimeType == 'audio/x-wav') {
      return pcm;
    }
    return pcmToWav(pcm, sampleRate: 24000, channels: 1, bitsPerSample: 16);
  }

  @override
  Future<List<String>> synthesizeToFiles({
    required String text,
    required String outputDir,
    required String baseName,
  }) async {
    final chunks = TextChunker.split(text);
    if (chunks.isEmpty) {
      throw TtsSynthesisException('Texte vide pour la synthèse audio.');
    }

    final paths = <String>[];
    for (var i = 0; i < chunks.length; i++) {
      final path = '$outputDir/${baseName}_$i.wav';
      await synthesizeChunk(text: chunks[i], outputPath: path);
      paths.add(path);
    }
    return paths;
  }
}
