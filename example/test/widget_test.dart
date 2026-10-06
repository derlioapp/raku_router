// Smoke tests: the example app builds, and its 404 → feed flow works.
import 'package:flutter_test/flutter_test.dart';

import 'package:raku_router_example/main.dart';

void main() {
  testWidgets('ExampleApp builds and renders', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();

    expect(find.byType(ExampleApp), findsOneWidget);
  });

  testWidgets('the typed 404 leads home with context.go', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await router.go(const NotFound('nope'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't find /nope"), findsOneWidget);

    await tester.tap(find.text('Go to the feed'));
    await tester.pumpAndSettle();
    expect(router.current.value, const Feed());
    expect(find.text('Note 1'), findsOneWidget);
  });
}
