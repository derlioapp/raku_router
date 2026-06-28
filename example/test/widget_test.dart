// A smoke test: the example app builds and renders its first screen.
import 'package:flutter_test/flutter_test.dart';

import 'package:raku_router_example/main.dart';

void main() {
  testWidgets('ExampleApp builds and renders', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();

    expect(find.byType(ExampleApp), findsOneWidget);
  });
}
