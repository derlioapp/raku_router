// End-to-end for the tree delegate WITH tabs: a deep link resolves into the
// right tab and rebuilds that branch's stack; switching tabs updates the URL;
// and `context.push` is level-routed — a tab route lands in the active tab,
// a top-level route lands full-page above the shell.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raku_router/raku_router.dart';

import 'fixtures.dart';

// A feed screen with two push buttons: one in-tab (Note), one full-page (Photo).
class _Feed extends StatelessWidget {
  const _Feed();
  @override
  Widget build(BuildContext context) => Column(
        children: [
          const Text('feed'),
          TextButton(
            onPressed: () => context.push(const Note('5')),
            child: const Text('open-note'),
          ),
          TextButton(
            onPressed: () => context.push(const FullScreen('9')),
            child: const Text('open-photo'),
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
            // A tab route that redirects to a full-page (root) route.
            route(
              '/redirect',
              (_) => const ToFullScreen(),
              (_) => const Text('redirect'),
            ),
          ],
          [route('/settings', (_) => const Plain(), (_) => const Text('set'))],
        ],
      ),
      // Top-level full-page route (above the shell).
      route(
        '/photo/:id',
        (p) => FullScreen(p('id')),
        (n) => Text('photo-${n.id}'),
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a deep link resolves into the right tab and rebuilds its stack',
      (
    tester,
  ) async {
    final config = _config();
    addTearDown(() => (config.routerDelegate as ChangeNotifier).dispose());
    await tester.pumpWidget(MaterialApp.router(routerConfig: config));
    await tester.pumpAndSettle();
    expect(find.text('feed'), findsOneWidget);

    // Deep link to /feed/notes/42 → the feed tab rebuilds as [Feed, Note(42)].
    final loc = await config.routeInformationParser!.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/feed/notes/42')),
    );
    await config.routerDelegate.setNewRoutePath(loc);
    await tester.pumpAndSettle();
    expect(find.text('note-42'), findsOneWidget);
    expect(config.routerDelegate.currentConfiguration, const Note('42'));

    // Back returns to the reconstructed ancestor (the feed root), not out.
    expect(await config.routerDelegate.popRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('feed'), findsOneWidget);
  });

  testWidgets('switching tabs updates the active configuration and URL', (
    tester,
  ) async {
    final config = _config();
    addTearDown(() => (config.routerDelegate as ChangeNotifier).dispose());
    await tester.pumpWidget(MaterialApp.router(routerConfig: config));
    await tester.pumpAndSettle();

    _controller!.go(1);
    await tester.pumpAndSettle();
    expect(find.text('set'), findsOneWidget);
    final active = config.routerDelegate.currentConfiguration!;
    expect(active, const Plain());
    expect(
      config.routeInformationParser!.restoreRouteInformation(active)?.uri,
      Uri.parse('/settings'),
    );
  });

  testWidgets('context.push of a tab route lands in the active tab', (
    tester,
  ) async {
    final config = _config();
    addTearDown(() => (config.routerDelegate as ChangeNotifier).dispose());
    await tester.pumpWidget(MaterialApp.router(routerConfig: config));
    await tester.pumpAndSettle();

    await tester.tap(find.text('open-note'));
    await tester.pumpAndSettle();
    expect(find.text('note-5'), findsOneWidget);
    expect(config.routerDelegate.currentConfiguration, const Note('5'));
    // The shell is still mounted underneath (the bar didn't get covered).
    expect(_controller!.index, 0);
  });

  testWidgets(
      'a deep link to a tab route that redirects to a full-page route '
      'lands above the shell', (tester) async {
    final config = _config();
    addTearDown(() => (config.routerDelegate as ChangeNotifier).dispose());
    await tester.pumpWidget(MaterialApp.router(routerConfig: config));
    await tester.pumpAndSettle();

    // /redirect → ToFullScreen → FullScreen('x') → /photo/x, full-page.
    final loc = await config.routeInformationParser!.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/redirect')),
    );
    await config.routerDelegate.setNewRoutePath(loc);
    await tester.pumpAndSettle();
    expect(find.text('photo-x'), findsOneWidget);
    expect(config.routerDelegate.currentConfiguration, const FullScreen('x'));

    // Back returns to the preserved tab shell underneath.
    expect(await config.routerDelegate.popRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('feed'), findsOneWidget);
  });

  testWidgets('context.push of a top-level route covers the shell', (
    tester,
  ) async {
    final config = _config();
    addTearDown(() => (config.routerDelegate as ChangeNotifier).dispose());
    await tester.pumpWidget(MaterialApp.router(routerConfig: config));
    await tester.pumpAndSettle();

    await tester.tap(find.text('open-photo'));
    await tester.pumpAndSettle();
    expect(find.text('photo-9'), findsOneWidget);
    expect(config.routerDelegate.currentConfiguration, const FullScreen('9'));

    // Back returns to the tab shell, which sat underneath at its initial state.
    expect(await config.routerDelegate.popRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('feed'), findsOneWidget);
  });
}
