import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'text_chunker.dart';
import 'tts_provider.dart';

class CloudTtsProvider implements TtsProvider {
  CloudTtsProvider({
    required this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;

  @override
  Future<String> synthesizeChunk({
    required String text,
    required String outputPath,
  }) async {
    final response = await _client.post(
      Uri.parse('https://api.openai.com/v1/audio/speech'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'tts-1',
        'input': text,
        'voice': 'alloy',
        'response_format': 'mp3',
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TtsSynthesisException(
        'Échec TTS cloud (code ${response.statusCode}).',
      );
    }

    await File(outputPath).writeAsBytes(response.bodyBytes);
    return outputPath;
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
      final path = '$outputDir/${baseName}_$i.mp3';
      await synthesizeChunk(text: chunks[i], outputPath: path);
      paths.add(path);
    }
    return paths;
  }
}
