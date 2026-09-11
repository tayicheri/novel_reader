import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:kokoro_tts_flutter/kokoro_tts_flutter.dart';

import '../../../core/kokoro_voice_options.dart';
import '../tts_provider.dart';
import 'kokoro_model_store.dart';

/// Abstraction around the ONNX Kokoro engine so tests can inject a fake.
abstract class KokoroRuntime {
  int get sampleRate;

  Future<void> ensureReady();

  Future<List<double>> generate({
    required String text,
    required String voice,
    required String languageCode,
  });
}

class OnDeviceKokoroRuntime implements KokoroRuntime {
  OnDeviceKokoroRuntime({KokoroModelStore? store})
      : _store = store ?? KokoroModelStore.instance;

  static const _styleDim = 256;
  static const _styleFrames = 510;

  final KokoroModelStore _store;
  final Tokenizer _tokenizer = Tokenizer();
  final OnnxRuntime _ort = OnnxRuntime();
  OrtSession? _session;
  final Map<String, List<Float32List>> _voices = {};
  Future<void>? _init;

  @override
  int get sampleRate => 24000;

  @override
  Future<void> ensureReady() {
    return _init ??= _doInit();
  }

  Future<void> _doInit() async {
    try {
      final paths = await _store.ensureReady();
      await _tokenizer.ensureInitialized();
      _session = await _ort.createSession(paths.modelPath);
      for (final option in kokoroVoiceOptions) {
        final file = File(_store.voicePath(paths.voicesDir, option.id));
        _voices[option.id] = _styleVectorsFromBytes(await file.readAsBytes());
      }
    } catch (error) {
      _init = null;
      throw TtsSynthesisException(
        'Impossible d\'initialiser Kokoro : $error',
      );
    }
  }

  List<Float32List> _styleVectorsFromBytes(Uint8List bytes) {
    final floats = bytes.buffer.asFloat32List();
    if (floats.length < _styleDim) {
      throw TtsSynthesisException('Fichier de voix Kokoro invalide.');
    }
    final frames = floats.length ~/ _styleDim;
    final vectors = <Float32List>[];
    for (var i = 0; i < frames && i < _styleFrames; i++) {
      vectors.add(
        Float32List.fromList(
          floats.sublist(i * _styleDim, (i + 1) * _styleDim),
        ),
      );
    }
    return vectors;
  }

  @override
  Future<List<double>> generate({
    required String text,
    required String voice,
    required String languageCode,
  }) async {
    await ensureReady();
    final session = _session;
    if (session == null) {
      throw TtsSynthesisException('Moteur Kokoro non initialisé.');
    }
    final styles = _voices[voice] ?? _voices[defaultKokoroVoiceId];
    if (styles == null || styles.isEmpty) {
      throw TtsSynthesisException('Voix Kokoro inconnue : $voice');
    }

    try {
      final phonemes = await _tokenizer.phonemize(
        text,
        lang: kokoroPhonemeLanguage(languageCode),
      );
      final tokens = _tokenizer.tokenize(phonemes);
      if (tokens.isEmpty) {
        throw TtsSynthesisException('Aucun phonème Kokoro généré.');
      }
      final style = styles[tokens.length.clamp(0, styles.length - 1)];
      return await _runInference(session, tokens, style);
    } catch (error) {
      if (error is TtsSynthesisException) rethrow;
      throw TtsSynthesisException('Échec de la synthèse Kokoro : $error');
    }
  }

  Future<List<double>> _runInference(
    OrtSession session,
    List<int> tokens,
    Float32List style,
  ) async {
    final padded = [0, ...tokens, 0];
    final inputNames = session.inputNames;
    if (inputNames.length < 3) {
      throw TtsSynthesisException('Modèle Kokoro inattendu.');
    }

    final inputs = <String, OrtValue>{};
    final tokenKey =
        inputNames.contains('input_ids') ? 'input_ids' : inputNames[0];
    final styleKey = inputNames.contains('style') ? 'style' : inputNames[1];
    final speedKey = inputNames.contains('speed') ? 'speed' : inputNames[2];

    inputs[tokenKey] = await OrtValue.fromList(
      Int64List.fromList(padded),
      [1, padded.length],
    );
    inputs[styleKey] = await OrtValue.fromList(
      style.toList(),
      [1, style.length],
    );
    inputs[speedKey] = await OrtValue.fromList([1.0], [1]);

    final outputs = await session.run(inputs);
    final outputNames = session.outputNames;
    if (outputNames.isEmpty || outputs.isEmpty) {
      throw TtsSynthesisException('Sortie audio Kokoro vide.');
    }
    final outputValue = outputs[outputNames.first];
    if (outputValue == null) {
      throw TtsSynthesisException('Sortie audio Kokoro vide.');
    }
    final raw = await outputValue.asList();
    return _flattenAudio(raw);
  }

  List<double> _flattenAudio(Object raw) {
    if (raw is List<double>) return raw;
    if (raw is Float32List) return raw;
    if (raw is List) {
      if (raw.isEmpty) return const [];
      if (raw.first is List) {
        return _flattenAudio(raw.first);
      }
      return raw.map((value) => (value as num).toDouble()).toList();
    }
    throw TtsSynthesisException('Format audio Kokoro inattendu.');
  }
}
