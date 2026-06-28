// State restoration: the tree router is a standard Navigator 2.0 RouterConfig, so
// setting `restorationScopeId` on MaterialApp.router restores the navigation
// location across process death — Flutter saves the current RouteInformation and
// re-feeds it to a fresh delegate on restart, which reconstructs the stack.
//
// These tests are faithful to process death: the router lives in State, so
// `restartAndRestore` destroys it and only the restoration framework can bring
// the location back (a negative case without restoration proves it).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raku_router/raku_router.dart';

class _Home extends RakuRoute {
  const _Home();
}

class _Note extends RakuRoute {
  const _Note(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class _Settings extends RakuRoute {
  const _Settings();
}

class _HomeScreen extends StatelessWidget {
  const _HomeScreen();
  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: () => context.push(const _Note('42')),
        child: const Text('home'),
      );
}

// The most-recently-built app's config, so a test can drive a platform URL
// change (the shell has no in-test tab-tap affordance).
RouterConfig<RakuRoute>? _lastConfig;

class _App extends StatefulWidget {
  const _App({this.restore = true, this.tabs = false});
  final bool restore;
  final bool tabs;
  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  late final RouterConfig<RakuRoute> _config = _lastConfig = raku(
    initial: const _Home(),
    routes: widget.tabs
        ? [
            tabs(
              shell: (context, controller, child) => child,
              branches: [
                [route('/', (_) => const _Home(), (_) => const _HomeScreen())],
                [
                  route(
                    '/settings',
                    (_) => const _Settings(),
                    (_) => const Text('settings'),
                  ),
                ],
              ],
            ),
          ]
        : [
            route(
              '/',
              (_) => const _Home(),
              (_) => const _HomeScreen(),
              children: [
                route(
                  'notes/:id',
                  (p) => _Note(p('id')),
                  (n) => Text('note-${n.id}'),
                ),
              ],
            ),
          ],
  );

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        routerConfig: _config,
        restorationScopeId: widget.restore ? 'app' : null,
      );
}

void main() {
  testWidgets('the navigation location is restored across process death',
      (tester) async {
    await tester.pumpWidget(
      const RootRestorationScope(restorationId: 'root', child: _App()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('home')); // push Note('42') → /notes/42
    await tester.pumpAndSettle();
    expect(find.text('note-42'), findsOneWidget);

    await tester.restartAndRestore();
    await tester.pumpAndSettle();

    // A fresh delegate would start at '/'; restoration brought back /notes/42.
    expect(find.text('note-42'), findsOneWidget);
    expect(find.text('home'), findsNothing);
  });

  testWidgets('without restorationScopeId the location is NOT restored',
      (tester) async {
    // The discriminator: same faithful restart, restoration off → back to home.
    await tester.pumpWidget(
      const RootRestorationScope(
        restorationId: 'root',
        child: _App(restore: false),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
    expect(find.text('note-42'), findsOneWidget);

    await tester.restartAndRestore();
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(find.text('note-42'), findsNothing);
  });

  testWidgets('restoration restores the active tab', (tester) async {
    await tester.pumpWidget(
      const RootRestorationScope(
        restorationId: 'root',
        child: _App(tabs: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);

    // Navigate (platform) to the settings tab, then die + restore.
    final config = _lastConfig!;
    final loc = await config.routeInformationParser!.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/settings')),
    );
    await config.routerDelegate.setNewRoutePath(loc);
    await tester.pumpAndSettle();
    expect(find.text('settings'), findsOneWidget);

    await tester.restartAndRestore();
    await tester.pumpAndSettle();
    expect(find.text('settings'), findsOneWidget);
  });
}
