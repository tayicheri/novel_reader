import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:tayi_whisper/app.dart';
import 'package:tayi_whisper/core/hive_boxes.dart';
import 'package:tayi_whisper/data/models/favorite_work.dart';
import 'package:tayi_whisper/data/repositories/favorites_repository.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Hive.init('./.dart_tool/widget_test_hive');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(FavoriteWorkAdapter());
    }
    if (Hive.isBoxOpen(HiveBoxes.favorites)) {
      await Hive.box<FavoriteWork>(HiveBoxes.favorites).clear();
    } else {
      await Hive.openBox<FavoriteWork>(HiveBoxes.favorites);
    }
    FavoritesRepository.instance.init();
  });

  testWidgets('Tayi Whisper home screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const TayiWhisperApp());
    await tester.pumpAndSettle();

    expect(find.text('Tayi Whisper'), findsOneWidget);
    expect(find.text('Charger'), findsOneWidget);
    expect(find.text('Mes favoris'), findsOneWidget);
  });
}
