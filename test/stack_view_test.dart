// Widget coverage for RouteStackView: the Router/delegate path, the scope
// helpers, a custom pageBuilder, and a RouteTransition route's own page.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raku_router/raku_router.dart';

import 'fixtures.dart';

void main() {
  testWidgets('RouteStackScope.of exposes the stack to descendants',
      (tester) async {
    final stack = RouteStack(const Home());
    addTearDown(stack.dispose);
    late RouteStack found;

    await tester.pumpWidget(
      MaterialApp(
        home: RouteStackView(
          stack: stack,
          builder: (context, route) {
            found = RouteStackScope.of(context);
            return const Text('x');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(found, same(stack));
  });

  testWidgets('scope helpers degrade gracefully without a scope',
      (tester) async {
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          expect(RouteStackScope.maybeOf(context), isNull);
          expect(() => RouteStackScope.of(context), throwsAssertionError);
          expect(context.routeStackOrNull, isNull);
          expect(() => context.routeStack, throwsAssertionError);
          return const SizedBox.shrink();
        },
      ),
    );
  });

  testWidgets('context.routeStack extension reads the enclosing stack',
      (tester) async {
    final stack = RouteStack(const Home());
    addTearDown(stack.dispose);
    late RouteStack viaExtension;
    RouteStack? viaOrNull;

    await tester.pumpWidget(
      MaterialApp(
        home: RouteStackView(
          stack: stack,
          builder: (context, route) {
            viaExtension = context.routeStack;
            viaOrNull = context.routeStackOrNull;
            return const Text('x');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(viaExtension, same(stack));
    expect(viaOrNull, same(stack));
  });

  testWidgets('a custom pageBuilder backs default routes', (tester) async {
    final stack = RouteStack(const Home());
    addTearDown(stack.dispose);
    var calls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: RouteStackView(
          stack: stack,
          builder: buildScreen,
          pageBuilder: (child, key, name) {
            calls++;
            return RakuPage<Object?>(key: key, name: name, child: child);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, greaterThan(0));
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('a RouteTransition route supplies its own page', (tester) async {
    final stack = RouteStack(const Home());
    await stack.push(const Sheet());
    addTearDown(stack.dispose);

    await tester.pumpWidget(
      MaterialApp(home: RouteStackView(stack: stack, builder: buildScreen)),
    );
    await tester.pumpAndSettle();
    expect(find.text('sheet'), findsOneWidget);
  });

  testWidgets('context.push / replace / pop drive the enclosing stack',
      (tester) async {
    final stack = RouteStack(const Home());
    addTearDown(stack.dispose);
    late BuildContext ctx;

    await tester.pumpWidget(
      MaterialApp(
        home: RouteStackView(
          stack: stack,
          builder: (context, route) {
            ctx = context;
            return buildScreen(context, route);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await ctx.push(const Note('1'));
    await tester.pumpAndSettle();
    expect(stack.current, const Note('1'));

    await ctx.replace(const Plain());
    await tester.pumpAndSettle();
    expect(stack.current, const Plain());

    await ctx.pop();
    await tester.pumpAndSettle();
    expect(stack.current, const Home());
  });

  testWidgets(
      'resolveTransition applies a per-route transition over the default',
      (tester) async {
    final stack = RouteStack(const Home());
    addTearDown(stack.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: RouteStackView(
          stack: stack,
          builder: (context, route) => Text(
            switch (route as TestRoute) {
              Home() => 'home',
              Plain() => 'plain',
              _ => '?',
            },
          ),
          transitionsBuilder: RakuTransitions.none, // global default: none
          resolveTransition: (route) => route is Plain
              ? RakuTransitions.slideIn(from: SlideFrom.bottom)
              : null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await stack.push(const Plain());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final midY = tester.getTopLeft(find.text('plain')).dy;
    await tester.pumpAndSettle();
    final settledY = tester.getTopLeft(find.text('plain')).dy;

    expect(midY, greaterThan(settledY), reason: 'Plain used its own slideIn');
  });

  test('RouteStack.fromRoutes pre-populates and exposes its value', () {
    final s = RouteStack.fromRoutes(const [Home(), Plain()]);
    addTearDown(s.dispose);
    expect(s.length, 2);
    expect(s.value, const [Home(), Plain()]);
    expect(s.current, const Plain());
  });
}
