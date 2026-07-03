import 'package:flutter_test/flutter_test.dart';

import 'package:tayi_whisper/app.dart';

void main() {
  testWidgets('Tayi Whisper home screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const TayiWhisperApp());
    await tester.pumpAndSettle();

    expect(find.text('Tayi Whisper'), findsOneWidget);
    expect(find.text('Charger'), findsOneWidget);
  });
}
