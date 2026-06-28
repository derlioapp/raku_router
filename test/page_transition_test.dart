// TST-04 — pages & transitions: none/fade/slide render, the RouteTransition
// mixin overrides the default page, and onDidRemovePage keeps the stack in sync
// after an imperative Navigator.pop.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raku_router/raku_router.dart';

import 'fixtures.dart';

void main() {
  Widget wrap(Widget Function(BuildContext) build) => Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(builder: build),
      );

  testWidgets('none renders the child with no transition wrapper',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        (c) => RakuTransitions.none(
          c,
          kAlwaysCompleteAnimation,
          kAlwaysDismissedAnimation,
          const Text('x'),
        ),
      ),
    );
    expect(find.text('x'), findsOneWidget);
    expect(find.byType(FadeTransition), findsNothing);
    expect(find.byType(SlideTransition), findsNothing);
  });

  testWidgets('fade wraps the child in a FadeTransition', (tester) async {
    await tester.pumpWidget(
      wrap(
        (c) => RakuTransitions.fade(
          c,
          kAlwaysCompleteAnimation,
          kAlwaysDismissedAnimation,
          const Text('x'),
        ),
      ),
    );
    expect(find.byType(FadeTransition), findsOneWidget);
    expect(find.text('x'), findsOneWidget);
  });

  testWidgets('slide nests two SlideTransitions', (tester) async {
    await tester.pumpWidget(
      wrap(
        (c) => RakuTransitions.slide(
          c,
          kAlwaysCompleteAnimation,
          kAlwaysDismissedAnimation,
          const Text('x'),
        ),
      ),
    );
    expect(find.byType(SlideTransition), findsNWidgets(2));
    expect(find.text('x'), findsOneWidget);
  });

  test('a RouteTransition route overrides the default page', () {
    final page = const Sheet().buildPage(const Text('x'), const ValueKey('k'));
    expect(page, isA<RakuPage<Object?>>());
    expect(
      (page as RakuPage).transitionsBuilder,
      RakuTransitions.slide,
    );
    expect(page.key, const ValueKey('k'));
  });

  testWidgets('onDidRemovePage syncs the stack after an imperative pop',
      (tester) async {
    final stack = RouteStack(const Home());
    await stack.push(const Plain());
    addTearDown(stack.dispose);

    await tester.pumpWidget(
      MaterialApp(home: RouteStackView(stack: stack, builder: buildScreen)),
    );
    await tester.pumpAndSettle();
    expect(find.text('plain'), findsOneWidget);

    // A screen calling Navigator.pop() directly must keep the RouteStack in
    // sync — RouteStackView wires Navigator.onDidRemovePage → handlePageRemoved.
    tester.state<NavigatorState>(find.byType(Navigator).last).pop();
    await tester.pumpAndSettle();

    expect(stack.length, 1);
    expect(stack.current, const Home());
    expect(find.text('home'), findsOneWidget);
  });
}
