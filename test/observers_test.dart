// raku(observers:) attaches NavigatorObservers to the navigators. It is a
// factory (not a list) because one observer instance can attach to only one
// Navigator, and Raku builds several — the root plus one per tab branch. The
// factory is called once per navigator, so each gets fresh instances and an
// observer sees in-tab pushes, not just top-level ones.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raku_router/raku_router.dart';

import 'fixtures.dart';

class _RecordingObserver extends NavigatorObserver {
  final List<String> pushed = <String>[];
  final List<String> popped = <String>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route.settings.name ?? '');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popped.add(route.settings.name ?? '');
  }
}

class _Feed extends StatelessWidget {
  const _Feed();
  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          TextButton(
            onPressed: () => context.push(const Note('5')),
            child: const Text('note'),
          ),
          TextButton(
            onPressed: () => context.push(const FullScreen('9')),
            child: const Text('photo'),
          ),
        ],
      );
}

BranchedRouteStack? _controller;

RouterConfig<RakuRoute> _config(List<_RecordingObserver> created) {
  _controller = null;
  return raku(
    initial: const Home(),
    observers: () {
      final observer = _RecordingObserver();
      created.add(observer);
      return <NavigatorObserver>[observer];
    },
    routes: [
      tabs(
        shell: (context, controller, child) {
          _controller = controller;
          return child;
        },
        branches: [
          [
            route(
              '/feed',
              (_) => const Home(),
              (_) => const _Feed(),
              children: [
                route(
                  'notes/:id',
                  (p) => Note(p('id')),
                  (n) => Text('note-${n.id}'),
                ),
              ],
            ),
          ],
          [route('/settings', (_) => const Plain(), (_) => const Text('set'))],
        ],
      ),
      route(
        '/photo/:id',
        (p) => FullScreen(p('id')),
        (n) => Text('full-${n.id}'),
      ),
    ],
  );
}

void main() {
  testWidgets('each navigator gets its own fresh observer instances',
      (tester) async {
    final created = <_RecordingObserver>[];
    final config = _config(created);
    addTearDown(() => (config.routerDelegate as ChangeNotifier).dispose());
    await tester.pumpWidget(MaterialApp.router(routerConfig: config));
    await tester.pumpAndSettle();

    // The root navigator and the (lazily built) active feed branch each got a
    // distinct observer — the same instance is never shared across navigators.
    expect(created.length, 2, reason: 'root + active feed branch');
    expect(
      created.toSet().length,
      created.length,
      reason: 'distinct instances',
    );

    final root = created[0];
    final feed = created[1];
    // The root navigator hosts the tabs shell sentinel; the feed branch hosts
    // the feed screen.
    expect(root.pushed.single, '_ShellSentinel');
    expect(feed.pushed.single, 'Home');

    // An in-tab push is seen by the branch observer, not the root.
    await tester.tap(find.text('note'));
    await tester.pumpAndSettle();
    expect(feed.pushed, ['Home', 'Note']);
    expect(root.pushed, ['_ShellSentinel']);

    // Pop it (uncovering the feed buttons) so we can push a full-page route.
    _controller!.activeStack.pop();
    await tester.pumpAndSettle();
    expect(feed.popped, ['Note']);

    // A full-page push lands on the root navigator, seen by the root observer.
    await tester.tap(find.text('photo'));
    await tester.pumpAndSettle();
    expect(root.pushed, ['_ShellSentinel', 'FullScreen']);
    expect(
      feed.pushed,
      ['Home', 'Note'],
      reason: 'root push not seen by branch',
    );
  });

  testWidgets('a branch observer is created when its tab is first shown',
      (tester) async {
    final created = <_RecordingObserver>[];
    final config = _config(created);
    addTearDown(() => (config.routerDelegate as ChangeNotifier).dispose());
    await tester.pumpWidget(MaterialApp.router(routerConfig: config));
    await tester.pumpAndSettle();
    expect(created.length, 2);

    // The settings branch is built lazily on first visit → its own observer.
    _controller!.go(1);
    await tester.pumpAndSettle();
    expect(created.length, 3);
    expect(created[2].pushed.single, 'Plain');
  });
}
