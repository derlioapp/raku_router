// System back with an imperatively shown overlay (dialog, bottom sheet) open
// dismisses the overlay first; only the *next* back pops the page underneath.
// Covers the Router (raku) mode — overlays on the root navigator and on a tab
// branch's navigator — and the plain RouteStackView mode.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raku_router/raku_router.dart';

import 'fixtures.dart';

RakuRouter _router({bool withTabs = false}) {
  final feed = route(
    '/',
    (_) => const Home(),
    (_) => const Text('home'),
    children: [
      route('notes/:id', (p) => Note(p('id')), (n) => Text('note-${n.id}')),
    ],
  );
  return raku(
    initial: const Home(),
    routes: [
      if (withTabs)
        tabs(
          shell: (context, tabs, child) => child,
          branches: [
            [feed],
            [route('/plain', (_) => const Plain(), (_) => const Text('plain'))],
          ],
        )
      else
        feed,
    ],
  );
}

Future<RakuRouter> _pumpOnNote(
  WidgetTester tester, {
  bool withTabs = false,
}) async {
  final router = _router(withTabs: withTabs);
  addTearDown(() => (router.routerDelegate as ChangeNotifier).dispose());
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  await router.push(const Note('1'));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  final overlays = <String, void Function(BuildContext)>{
    'dialog on the root navigator': (context) => showDialog<void>(
          context: context,
          builder: (_) => const Text('overlay'),
        ),
    'dialog on the nearest navigator': (context) => showDialog<void>(
          context: context,
          useRootNavigator: false,
          builder: (_) => const Text('overlay'),
        ),
    'bottom sheet': (context) => showModalBottomSheet<void>(
          context: context,
          builder: (_) => const Text('overlay'),
        ),
  };

  for (final withTabs in [false, true]) {
    for (final entry in overlays.entries) {
      testWidgets(
          'system back closes a ${entry.key} first '
          '(${withTabs ? 'tabs' : 'single stack'})', (tester) async {
        final router = await _pumpOnNote(tester, withTabs: withTabs);
        entry.value(tester.element(find.text('note-1')));
        await tester.pumpAndSettle();
        expect(find.text('overlay'), findsOneWidget);

        expect(await router.routerDelegate.popRoute(), isTrue);
        await tester.pumpAndSettle();
        expect(find.text('overlay'), findsNothing);
        expect(find.text('note-1'), findsOneWidget, reason: 'page kept');
        expect(router.current.value, const Note('1'));

        expect(await router.routerDelegate.popRoute(), isTrue);
        await tester.pumpAndSettle();
        expect(router.current.value, const Home());
      });
    }
  }

  testWidgets('an overlay\'s own PopScope still vetoes system back',
      (tester) async {
    final router = await _pumpOnNote(tester);
    showDialog<void>(
      context: tester.element(find.text('note-1')),
      builder: (_) => const PopScope(canPop: false, child: Text('overlay')),
    );
    await tester.pumpAndSettle();

    await router.routerDelegate.popRoute();
    await tester.pumpAndSettle();
    expect(find.text('overlay'), findsOneWidget);
    expect(router.current.value, const Note('1'));
  });

  testWidgets('plain RouteStackView: back closes a nested sheet first',
      (tester) async {
    final stack = RouteStack.fromRoutes(const [Home(), Note('1')]);
    addTearDown(stack.dispose);
    await tester.pumpWidget(
      MaterialApp(home: RouteStackView(stack: stack, builder: buildScreen)),
    );
    await tester.pumpAndSettle();
    showModalBottomSheet<void>(
      context: tester.element(find.text('note-1')),
      builder: (_) => const Text('overlay'),
    );
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('overlay'), findsNothing);
    expect(stack.value, const [Home(), Note('1')], reason: 'page kept');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(stack.value, const [Home()]);
  });
}
