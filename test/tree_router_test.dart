// End-to-end: a screen-tree router reconstructs the navigation stack from a
// URL's structure (web-grade), so a deep link into a nested route restores its
// back history.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raku_router/raku_router.dart';

import 'fixtures.dart';

RouterConfig<RakuRoute> _config() => raku(
      initial: const Home(),
      routes: [
        route(
          '/feed',
          (_) => const Home(),
          (_) => const Text('feed'),
          children: [
            route(
              'notes/:id',
              (p) => Note(p('id')),
              (n) => Center(child: Text('note-${n.id}')),
            ),
          ],
        ),
        route(
          '/about',
          (_) => const Plain(),
          (_) => const Text('about'),
        ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a deep link reconstructs the nested stack; back works',
      (tester) async {
    final config = _config();
    addTearDown(() => (config.routerDelegate as ChangeNotifier).dispose());

    await tester.pumpWidget(MaterialApp.router(routerConfig: config));
    await tester.pumpAndSettle();
    expect(find.text('feed'), findsOneWidget);

    // Deep link to /feed/notes/42 → the stack rebuilds as [Feed, Note(42)].
    final loc = await config.routeInformationParser!.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/feed/notes/42')),
    );
    await config.routerDelegate.setNewRoutePath(loc);
    await tester.pumpAndSettle();
    expect(find.text('note-42'), findsOneWidget);

    // Back pops to the reconstructed ancestor (Feed), not out of the app.
    expect(await config.routerDelegate.popRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('feed'), findsOneWidget);
  });

  test('parse / restore round-trip a route to its full URL', () async {
    final config = _config();
    addTearDown(() => (config.routerDelegate as ChangeNotifier).dispose());
    final parser = config.routeInformationParser!;

    final parsed = await parser.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/feed/notes/7')),
    );
    expect(parsed, const Note('7'));
    expect(
      parser.restoreRouteInformation(const Note('7'))?.uri,
      Uri.parse('/feed/notes/7'),
    );
  });

  testWidgets('a deep link to a redirecting route follows the redirect', (
    tester,
  ) async {
    final config = raku(
      initial: const Home(),
      routes: [
        route('/feed', (_) => const Home(), (_) => const Text('feed')),
        route('/legacy', (_) => const Legacy(), (_) => const Text('legacy')),
      ],
    );
    addTearDown(() => (config.routerDelegate as ChangeNotifier).dispose());
    await tester.pumpWidget(MaterialApp.router(routerConfig: config));
    await tester.pumpAndSettle();

    // /legacy parses to Legacy, which RouteRedirects to Home → renders /feed.
    final loc = await config.routeInformationParser!.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/legacy')),
    );
    await config.routerDelegate.setNewRoutePath(loc);
    await tester.pumpAndSettle();
    expect(find.text('feed'), findsOneWidget);
    expect(config.routerDelegate.currentConfiguration, const Home());
  });

  test('an unknown URL falls back through onUnknown', () async {
    final config = raku(
      initial: const Home(),
      onUnknown: (_) => const Plain(),
      routes: [route('/', (_) => const Home(), (_) => const Text('h'))],
    );
    addTearDown(() => (config.routerDelegate as ChangeNotifier).dispose());

    final parsed = await config.routeInformationParser!.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/missing')),
    );
    expect(parsed, const Plain());
  });

  test('without onUnknown, an unrecognised URL falls back to the initial', () {
    final config = _config(); // no onUnknown handler
    addTearDown(() => (config.routerDelegate as ChangeNotifier).dispose());

    return expectLater(
      config.routeInformationParser!.parseRouteInformation(
        RouteInformation(uri: Uri.parse('/totally/unknown')),
      ),
      completion(const Home()),
    );
  });

  testWidgets('system back (popRoute) is vetoed by a route guard', (
    tester,
  ) async {
    final config = raku(
      initial: const Home(),
      routes: [
        route(
          '/feed',
          (_) => const Home(),
          (_) => const Text('feed'),
          children: [
            route(
              'locked',
              (_) => const Guarded(allow: false),
              (_) => const Text('locked'),
            ),
          ],
        ),
      ],
    );
    addTearDown(() => (config.routerDelegate as ChangeNotifier).dispose());
    await tester.pumpWidget(MaterialApp.router(routerConfig: config));
    await tester.pumpAndSettle();

    final loc = await config.routeInformationParser!.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/feed/locked')),
    );
    await config.routerDelegate.setNewRoutePath(loc);
    await tester.pumpAndSettle();
    expect(find.text('locked'), findsOneWidget);

    // The guard vetoes system back; the screen stays put.
    expect(await config.routerDelegate.popRoute(), isFalse);
    await tester.pumpAndSettle();
    expect(find.text('locked'), findsOneWidget);
  });

  testWidgets('the initial address is the initial route\'s full URL',
      (tester) async {
    final config = _config();
    addTearDown(() => (config.routerDelegate as ChangeNotifier).dispose());
    expect(config.routeInformationProvider!.value.uri, Uri.parse('/feed'));
  });
}
