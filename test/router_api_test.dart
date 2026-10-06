// RakuRouter as a navigation handle for code without a BuildContext (push
// notifications, auth listeners): `go` rebuilds the location like a deep link,
// `push` lands at the right level, `current` is a listenable active leaf, and
// `context.go` is the in-widget equivalent. Also: a slow async redirect can't
// overwrite a newer navigation.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raku_router/raku_router.dart';

import 'fixtures.dart';

/// A redirect whose resolution the test controls.
class Gate extends RakuRoute with RouteRedirect {
  const Gate();
  static Completer<RakuRoute?> completer = Completer<RakuRoute?>();
  @override
  Future<RakuRoute?> redirect() => completer.future;
}

BranchedRouteStack? _tabs;

RakuRouter _router({void Function(RakuRoute)? onNavigation}) {
  _tabs = null;
  return raku(
    initial: const Home(),
    onNavigation: onNavigation,
    routes: [
      tabs(
        shell: (context, tabs, child) {
          _tabs = tabs;
          return child;
        },
        branches: [
          [
            route(
              '/feed',
              (_) => const Home(),
              (_) => const Text('home'),
              children: [
                route(
                  'notes/:id',
                  (p) => Note(p('id')),
                  (n) => Text('note-${n.id}'),
                ),
                route(
                  'edit',
                  (_) => const Guarded(allow: false),
                  (_) => const Text('guarded'),
                ),
              ],
            ),
          ],
          [
            route(
              '/settings',
              (_) => const Plain(),
              (_) => const Text('plain'),
            ),
          ],
        ],
      ),
      route(
        '/photo/:id',
        (p) => FullScreen(p('id')),
        (n) => Text('full-${n.id}'),
      ),
      route('/legacy', (_) => const Legacy(), (_) => const Text('legacy')),
      route('/gate', (_) => const Gate(), (_) => const Text('gate')),
    ],
  );
}

Future<RakuRouter> _pump(
  WidgetTester tester, {
  void Function(RakuRoute)? onNavigation,
}) async {
  final router = _router(onNavigation: onNavigation);
  addTearDown(() => (router.routerDelegate as ChangeNotifier).dispose());
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('go rebuilds the location from the URL, like a deep link',
      (tester) async {
    final router = await _pump(tester);

    await router.go(const Note('42'));
    await tester.pumpAndSettle();
    expect(find.text('note-42'), findsOneWidget);
    expect(router.current.value, const Note('42'));

    // The ancestors became the back stack.
    expect(await router.routerDelegate.popRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('go switches tabs and follows redirects', (tester) async {
    final router = await _pump(tester);

    await router.go(const Plain());
    await tester.pumpAndSettle();
    expect(_tabs!.index, 1);
    expect(find.text('plain'), findsOneWidget);

    await router.go(const Legacy()); // Legacy → Home
    await tester.pumpAndSettle();
    expect(router.current.value, const Home());
    expect(_tabs!.index, 0);
  });

  testWidgets('go is an explicit app decision: guards do not veto it',
      (tester) async {
    final router = await _pump(tester);
    await router.go(const Guarded(allow: false));
    await tester.pumpAndSettle();
    expect(find.text('guarded'), findsOneWidget);

    await router.go(const Plain()); // e.g. sign-out
    await tester.pumpAndSettle();
    expect(router.current.value, const Plain());
  });

  testWidgets('push lands at the route\'s level (tab vs full-page)',
      (tester) async {
    final router = await _pump(tester);

    await router.push(const Note('1'));
    await tester.pumpAndSettle();
    expect(find.text('note-1'), findsOneWidget);
    expect(_tabs!.activeStack.current, const Note('1'), reason: 'in the tab');

    await router.push(const FullScreen('9'));
    await tester.pumpAndSettle();
    expect(find.text('full-9'), findsOneWidget);
    expect(_tabs!.activeStack.current, const Note('1'), reason: 'above shell');
  });

  testWidgets('current notifies on every change; onNavigation agrees',
      (tester) async {
    final reported = <RakuRoute>[];
    final router = await _pump(tester, onNavigation: reported.add);
    final seen = <RakuRoute>[];
    router.current.addListener(() => seen.add(router.current.value));

    expect(router.current.value, const Home());
    await router.push(const Note('1'));
    await tester.pumpAndSettle();
    _tabs!.go(1);
    await tester.pumpAndSettle();
    await router.routerDelegate.popRoute(); // nothing to pop in settings
    _tabs!.go(0);
    await tester.pumpAndSettle();

    expect(seen, [const Note('1'), const Plain(), const Note('1')]);
    expect(reported, seen);
  });

  testWidgets('context.go works from a widget', (tester) async {
    final router = await _pump(tester);
    unawaited(tester.element(find.text('home')).go(const FullScreen('3')));
    await tester.pumpAndSettle();
    expect(router.current.value, const FullScreen('3'));
  });

  testWidgets('context.go outside raku() resets the nearest stack',
      (tester) async {
    final stack = RouteStack.fromRoutes(const [Home(), Note('1')]);
    addTearDown(stack.dispose);
    await tester.pumpWidget(
      MaterialApp(home: RouteStackView(stack: stack, builder: buildScreen)),
    );
    await tester.pumpAndSettle();

    await tester.element(find.text('note-1')).go(const Legacy());
    await tester.pumpAndSettle();
    expect(stack.value, const [Home()], reason: 'reset, redirect followed');
  });

  testWidgets('a slow redirect cannot overwrite a newer navigation',
      (tester) async {
    final router = await _pump(tester);
    Gate.completer = Completer<RakuRoute?>();

    final slow = router.go(const Gate()); // waits on the redirect…
    await router.go(const Plain()); // …while a newer navigation lands
    await tester.pumpAndSettle();
    expect(router.current.value, const Plain());

    Gate.completer.complete(const FullScreen('late'));
    await slow;
    await tester.pumpAndSettle();
    expect(router.current.value, const Plain(), reason: 'stale result dropped');
  });
}
