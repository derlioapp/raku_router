// A platform URL change (browser back/forward, a deep link) reconciles the live
// tree in place instead of rebuilding it: inactive branches keep their in-app
// history and unchanged screens keep their element state. A stateful counter
// screen makes that preservation observable — after teardown it would reset.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raku_router/raku_router.dart';

import 'fixtures.dart';

/// A screen whose [_CounterState.n] survives only if its element isn't rebuilt.
class _Counter extends StatefulWidget {
  const _Counter(this.label);
  final String label;
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int n = 0;
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text('${widget.label}:$n'),
          TextButton(
            onPressed: () => setState(() => n++),
            child: const Text('inc'),
          ),
        ],
      );
}

BranchedRouteStack? _controller;

RouterConfig<RakuRoute> _config() {
  _controller = null;
  return raku(
    initial: const Home(),
    routes: [
      tabs(
        shell: (context, tabs, child) {
          _controller = tabs;
          return child;
        },
        branches: [
          [route('/feed', (_) => const Home(), (_) => const _Counter('feed'))],
          [
            route(
              '/settings',
              (_) => const Plain(),
              (_) => const _Counter('set'),
            ),
          ],
        ],
      ),
      route(
        '/photo/:id',
        (p) => FullScreen(p('id')),
        (n) => Text('photo-${n.id}'),
      ),
    ],
  );
}

// Drive a platform URL change the way the engine would: parse, then set.
Future<void> _go(RouterConfig<RakuRoute> config, String url) async {
  final route = await config.routeInformationParser!.parseRouteInformation(
    RouteInformation(uri: Uri.parse(url)),
  );
  await config.routerDelegate.setNewRoutePath(route);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a full-page URL change preserves the shell underneath it',
      (tester) async {
    final config = _config();
    addTearDown(() => (config.routerDelegate as ChangeNotifier).dispose());
    await tester.pumpWidget(MaterialApp.router(routerConfig: config));
    await tester.pumpAndSettle();

    await tester.tap(find.text('inc'));
    await tester.tap(find.text('inc'));
    await tester.pumpAndSettle();
    expect(find.text('feed:2'), findsOneWidget);

    // Browser navigates to a full-page route, then back.
    await _go(config, '/photo/9');
    await tester.pumpAndSettle();
    expect(find.text('photo-9'), findsOneWidget);

    await _go(config, '/feed');
    await tester.pumpAndSettle();
    // The feed screen kept its counter across the round-trip (not rebuilt).
    expect(find.text('feed:2'), findsOneWidget);
  });

  testWidgets('switching the active tab by URL preserves the other tab',
      (tester) async {
    final config = _config();
    addTearDown(() => (config.routerDelegate as ChangeNotifier).dispose());
    await tester.pumpWidget(MaterialApp.router(routerConfig: config));
    await tester.pumpAndSettle();

    await tester.tap(find.text('inc'));
    await tester.pumpAndSettle();
    expect(find.text('feed:1'), findsOneWidget);

    // Platform makes Settings the active tab — Feed becomes inactive.
    await _go(config, '/settings');
    await tester.pumpAndSettle();
    expect(find.text('set:0'), findsOneWidget);

    // Return to Feed in-app (a tab tap): its counter survived the URL change.
    _controller!.go(0);
    await tester.pumpAndSettle();
    expect(find.text('feed:1'), findsOneWidget);
  });

  testWidgets('browser back/forward walks URL history with each tab intact',
      (tester) async {
    // The canonical web check: a sequence of platform URL changes (what the
    // browser delivers on back/forward) must land on the right screen AND keep
    // both tabs' state — never tear the tree down.
    final config = _config();
    addTearDown(() => (config.routerDelegate as ChangeNotifier).dispose());
    await tester.pumpWidget(MaterialApp.router(routerConfig: config));
    await tester.pumpAndSettle();

    await tester.tap(find.text('inc')); // feed:1
    await tester.pumpAndSettle();

    await _go(config, '/settings'); // navigate to the other tab
    await tester.pumpAndSettle();
    await tester.tap(find.text('inc')); // set:1
    await tester.pumpAndSettle();
    expect(find.text('set:1'), findsOneWidget);

    await _go(config, '/feed'); // browser BACK → feed, its counter preserved
    await tester.pumpAndSettle();
    expect(find.text('feed:1'), findsOneWidget);

    await _go(config, '/settings'); // browser FORWARD → settings still at 1
    await tester.pumpAndSettle();
    expect(find.text('set:1'), findsOneWidget);
  });

  testWidgets('a deeper URL in the active tab keeps the shared ancestor',
      (tester) async {
    // Feed root carries the counter; a deep link to a child must not rebuild it.
    final config = raku(
      initial: const Home(),
      routes: [
        tabs(
          shell: (context, tabs, child) => child,
          branches: [
            [
              route(
                '/feed',
                (_) => const Home(),
                (_) => const _Counter('feed'),
                children: [
                  route(
                    'notes/:id',
                    (p) => Note(p('id')),
                    (n) => Text('n-${n.id}'),
                  ),
                ],
              ),
            ],
            [
              route(
                '/settings',
                (_) => const Plain(),
                (_) => const Text('set'),
              ),
            ],
          ],
        ),
      ],
    );
    addTearDown(() => (config.routerDelegate as ChangeNotifier).dispose());
    await tester.pumpWidget(MaterialApp.router(routerConfig: config));
    await tester.pumpAndSettle();

    await tester.tap(find.text('inc'));
    await tester.pumpAndSettle();
    expect(find.text('feed:1'), findsOneWidget);

    // Deep link pushes Note on top of the *same* Feed ancestor.
    await _go(config, '/feed/notes/7');
    await tester.pumpAndSettle();
    expect(find.text('n-7'), findsOneWidget);

    // Pop back: the Feed ancestor was preserved, counter intact.
    expect(await config.routerDelegate.popRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('feed:1'), findsOneWidget);
  });
}
