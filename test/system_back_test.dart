// TST-05 — system back: the platform back gesture pops the stack through
// NavigatorPopHandler, and a RouteGuard vetoes it.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raku_router/raku_router.dart';

import 'fixtures.dart';

void main() {
  // Simulate the OS "back" by delivering the platform `popRoute` message.
  Future<void> systemBack(WidgetTester tester) async {
    final message = const JSONMethodCodec().encodeMethodCall(
      const MethodCall('popRoute'),
    );
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      message,
      (_) {},
    );
    await tester.pumpAndSettle();
  }

  testWidgets('system back pops the stack', (tester) async {
    final stack = RouteStack(const Home());
    await stack.push(const Plain());
    addTearDown(stack.dispose);

    await tester.pumpWidget(
      MaterialApp(home: RouteStackView(stack: stack, builder: buildScreen)),
    );
    await tester.pumpAndSettle();
    expect(find.text('plain'), findsOneWidget);

    await systemBack(tester);

    expect(stack.length, 1);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('a guard vetoes the system back gesture', (tester) async {
    final stack = RouteStack(const Home());
    await stack.push(const Guarded(allow: false));
    addTearDown(stack.dispose);

    await tester.pumpWidget(
      MaterialApp(home: RouteStackView(stack: stack, builder: buildScreen)),
    );
    await tester.pumpAndSettle();
    expect(find.text('guarded'), findsOneWidget);

    await systemBack(tester);

    expect(stack.length, 2, reason: 'guard blocks the pop');
    expect(find.text('guarded'), findsOneWidget);
  });
}
