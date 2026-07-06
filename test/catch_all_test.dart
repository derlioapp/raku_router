// A catch-all (`*`) route is a typed 404. Nested under a section it scopes the
// not-found to that subtree (staying in the right tab); at the top level it is
// the global fallback. A concrete route always beats a wildcard, the deepest
// matching wildcard wins, and the caught URL round-trips via RouteParams.rest.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raku_router/raku_router.dart';

class Feed extends RakuRoute {
  const Feed();
}

class NoteX extends RakuRoute {
  const NoteX(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class Settings extends RakuRoute {
  const Settings();
}

class Photo extends RakuRoute {
  const Photo(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class FeedNotFound extends RakuRoute {
  const FeedNotFound(this.path);
  final String path;
  @override
  List<Object?> get props => [path];
}

class GlobalNotFound extends RakuRoute {
  const GlobalNotFound(this.path);
  final String path;
  @override
  List<Object?> get props => [path];
}

BranchedRouteStack? controller;

RouterConfig<RakuRoute> _config() {
  controller = null;
  return raku(
    initial: const Feed(),
    routes: [
      tabs(
        shell: (context, c, child) {
          controller = c;
          return child;
        },
        branches: [
          [
            route(
              '/feed',
              (_) => const Feed(),
              (_) => const Text('feed'),
              children: [
                route(
                  'notes/:id',
                  (p) => NoteX(p('id')),
                  (n) => Text('note-${n.id}'),
                ),
                route(
                  '*',
                  (p) => FeedNotFound(p.rest),
                  (n) => Text('feed404-${n.path}'),
                ),
              ],
            ),
          ],
          [
            route(
              '/settings',
              (_) => const Settings(),
              (_) => const Text('settings'),
            ),
          ],
        ],
      ),
      route('/photo/:id', (p) => Photo(p('id')), (n) => Text('photo-${n.id}')),
      route(
        '*',
        (p) => GlobalNotFound(p.rest),
        (n) => Text('global404-${n.path}'),
      ),
    ],
  );
}

Future<void> _go(
  WidgetTester tester,
  RouterConfig<RakuRoute> config,
  String uri,
) async {
  final loc = await config.routeInformationParser!.parseRouteInformation(
    RouteInformation(uri: Uri.parse(uri)),
  );
  await config.routerDelegate.setNewRoutePath(loc);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a concrete route beats a wildcard', (tester) async {
    final config = _config();
    addTearDown(() => (config.routerDelegate as ChangeNotifier).dispose());
    await tester.pumpWidget(MaterialApp.router(routerConfig: config));
    await tester.pumpAndSettle();

    await _go(tester, config, '/feed/notes/42');
    expect(find.text('note-42'), findsOneWidget);
    expect(config.routerDelegate.currentConfiguration, const NoteX('42'));
  });

  testWidgets('a subtree catch-all handles an unknown URL under its prefix',
      (tester) async {
    final config = _config();
    addTearDown(() => (config.routerDelegate as ChangeNotifier).dispose());
    await tester.pumpWidget(MaterialApp.router(routerConfig: config));
    await tester.pumpAndSettle();

    // /feed/garbage → the feed section's own 404, stacked on Feed inside the tab.
    await _go(tester, config, '/feed/garbage/x');
    expect(find.text('feed404-garbage/x'), findsOneWidget);
    expect(
      config.routerDelegate.currentConfiguration,
      const FeedNotFound('garbage/x'),
    );

    // Back returns to the feed root (the 404 is stacked on it), not out of the app.
    expect(await config.routerDelegate.popRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('feed'), findsOneWidget);
  });

  testWidgets('the deepest catch-all wins over the global one', (tester) async {
    final config = _config();
    addTearDown(() => (config.routerDelegate as ChangeNotifier).dispose());
    await tester.pumpWidget(MaterialApp.router(routerConfig: config));
    await tester.pumpAndSettle();

    await _go(tester, config, '/feed/nope');
    expect(find.text('feed404-nope'), findsOneWidget);
    expect(find.text('global404-nope'), findsNothing);
  });

  testWidgets('a section without its own 404 falls through to the global one',
      (tester) async {
    final config = _config();
    addTearDown(() => (config.routerDelegate as ChangeNotifier).dispose());
    await tester.pumpWidget(MaterialApp.router(routerConfig: config));
    await tester.pumpAndSettle();

    // Settings declares no catch-all → the global 404 shows (full-page).
    await _go(tester, config, '/settings/garbage');
    expect(find.text('global404-settings/garbage'), findsOneWidget);

    // A URL under no section also hits the global 404.
    await _go(tester, config, '/totally/unknown');
    expect(find.text('global404-totally/unknown'), findsOneWidget);
  });

  test('a caught URL round-trips through the catch-all route', () {
    final config = _config();
    addTearDown(() => (config.routerDelegate as ChangeNotifier).dispose());
    final parser = config.routeInformationParser!;

    expect(
      parser.restoreRouteInformation(const FeedNotFound('garbage/x'))?.uri,
      Uri.parse('/feed/garbage/x'),
    );
    expect(
      parser.restoreRouteInformation(const GlobalNotFound('a/b'))?.uri,
      Uri.parse('/a/b'),
    );
  });
}
