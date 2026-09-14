import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:tayi_whisper/services/tts/native_tts_provider.dart';

class _RecordingTts extends FlutterTts {
  final calls = <String>[];
  IosTextToSpeechAudioCategory? category;
  List<IosTextToSpeechAudioCategoryOptions>? options;
  IosTextToSpeechAudioMode? mode;
  bool? sharedInstance;
  bool? autoStop;

  @override
  Future<dynamic> setLanguage(String language) async {
    calls.add('setLanguage');
    return 1;
  }

  @override
  Future<dynamic> awaitSynthCompletion(bool awaitCompletion) async {
    calls.add('awaitSynthCompletion');
    return 1;
  }

  @override
  Future<dynamic> setSharedInstance(bool sharedSession) async {
    calls.add('setSharedInstance');
    sharedInstance = sharedSession;
    return 1;
  }

  @override
  Future<dynamic> autoStopSharedSession(bool autoStop) async {
    calls.add('autoStopSharedSession');
    this.autoStop = autoStop;
    return 1;
  }

  @override
  Future<dynamic> setIosAudioCategory(
    IosTextToSpeechAudioCategory category,
    List<IosTextToSpeechAudioCategoryOptions> options, [
    IosTextToSpeechAudioMode mode = IosTextToSpeechAudioMode.defaultMode,
  ]) async {
    calls.add('setIosAudioCategory');
    this.category = category;
    this.options = options;
    this.mode = mode;
    return 1;
  }

  @override
  Future<dynamic> synthesizeToFile(
    String text,
    String fileName, [
    bool isFullPath = false,
  ]) async {
    calls.add('synthesizeToFile');
    await File(fileName).writeAsBytes(const [1, 2, 3]);
    return 1;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('native_tts');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('configure la session audio iOS pour le background', () async {
    final tts = _RecordingTts();
    final provider = NativeTtsProvider(
      tts: tts,
      languageCode: () => 'fr-FR',
      isIOS: true,
      isAndroid: false,
      isMacOS: false,
    );
    final path = '${tempDir.path}/chunk.caf';

    await provider.synthesizeChunk(text: 'Bonjour', outputPath: path);

    expect(tts.sharedInstance, isTrue);
    expect(tts.autoStop, isFalse);
    expect(tts.category, IosTextToSpeechAudioCategory.playback);
    expect(tts.options, [IosTextToSpeechAudioCategoryOptions.mixWithOthers]);
    expect(tts.mode, IosTextToSpeechAudioMode.spokenAudio);
    expect(
      tts.calls,
      containsAllInOrder([
        'setLanguage',
        'setSharedInstance',
        'setIosAudioCategory',
        'autoStopSharedSession',
        'awaitSynthCompletion',
        'synthesizeToFile',
      ]),
    );
  });

  test('ne reconfigure pas la session à chaque segment', () async {
    final tts = _RecordingTts();
    final provider = NativeTtsProvider(
      tts: tts,
      isIOS: true,
      isAndroid: false,
      isMacOS: false,
    );

    await provider.synthesizeChunk(
      text: 'Un',
      outputPath: '${tempDir.path}/a.caf',
    );
    await provider.synthesizeChunk(
      text: 'Deux',
      outputPath: '${tempDir.path}/b.caf',
    );

    expect(
      tts.calls.where((call) => call == 'setIosAudioCategory').length,
      1,
    );
    expect(
      tts.calls.where((call) => call == 'synthesizeToFile').length,
      2,
    );
  });
}
