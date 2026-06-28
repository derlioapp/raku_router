// raku(onNavigation:) reports the active leaf route — typed, not a raw
// Route<dynamic> — after every change that moves it (push, pop, tab switch,
// browser back/forward), once per change, and never for the initial route.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raku_router/raku_router.dart';

import 'fixtures.dart';

class _Feed extends StatelessWidget {
  const _Feed();
  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: () => context.push(const Note('5')),
        child: const Text('feed'),
      );
}

BranchedRouteStack? _controller;

RouterConfig<RakuRoute> _config(List<RakuRoute> log) {
  _controller = null;
  return raku(
    initial: const Home(),
    onNavigation: log.add,
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
                  (n) => Text('n-${n.id}'),
                ),
              ],
            ),
          ],
          [route('/settings', (_) => const Plain(), (_) => const Text('set'))],
        ],
      ),
    ],
  );
}

void main() {
  testWidgets('onNavigation reports typed routes, once per change, no initial',
      (tester) async {
    final log = <RakuRoute>[];
    final config = _config(log);
    addTearDown(() => (config.routerDelegate as ChangeNotifier).dispose());
    await tester.pumpWidget(MaterialApp.router(routerConfig: config));
    await tester.pumpAndSettle();

    // No event for the initial route.
    expect(log, isEmpty);

    // Push within the tab.
    await tester.tap(find.text('feed'));
    await tester.pumpAndSettle();
    expect(log, [const Note('5')]);

    // Switch tabs → the active leaf becomes the other branch's route.
    _controller!.go(1);
    await tester.pumpAndSettle();
    expect(log.last, const Plain());

    // Pop back to feed root via system back (Router popRoute).
    _controller!.go(0);
    await tester.pumpAndSettle();
    await config.routerDelegate.popRoute();
    await tester.pumpAndSettle();
    expect(log.last, const Home());

    // A browser back/forward (platform URL change) also reports.
    final loc = await config.routeInformationParser!.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/feed/notes/9')),
    );
    await config.routerDelegate.setNewRoutePath(loc);
    await tester.pumpAndSettle();
    expect(log.last, const Note('9'));
  });
}
