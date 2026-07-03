import 'package:flutter_test/flutter_test.dart';

import 'package:novel_reader/app.dart';

void main() {
  testWidgets('EchoRead home screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const NovelReaderApp());
    await tester.pumpAndSettle();

    expect(find.text('EchoRead'), findsOneWidget);
    expect(find.text('Charger'), findsOneWidget);
  });
}
