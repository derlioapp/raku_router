// On the web, the browser's back/forward buttons don't go through popRoute: they
// deliver a new URL (setNewRoutePath). A URL change that would remove a guarded
// page must be vetoed like the back button — onPopBlocked runs, the location is
// kept, and the address bar is put back — while a change that leaves the
// guarded page alive (e.g. switching to another tab) goes through.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raku_router/raku_router.dart';

class Home extends RakuRoute {
  const Home();
}

class Settings extends RakuRoute {
  const Settings();
}

final ValueNotifier<bool> _dirty = ValueNotifier<bool>(true);
final List<RouteStack> _blockedOn = <RouteStack>[];

/// An editor that blocks leaving while [_dirty]; on a blocked attempt it
/// records the stack its context resolves to, and confirms when asked.
class Editor extends RakuRoute with RouteGuard {
  const Editor();
  static bool confirm = false;
  @override
  bool get canPop => !_dirty.value;
  @override
  Listenable? get rebuildOn => _dirty;
  @override
  void onPopBlocked(BuildContext context) {
    _blockedOn.add(context.routeStack);
    if (confirm) {
      _dirty.value = false;
      context.pop();
    }
  }
}

BranchedRouteStack? _tabs;

Future<RakuRouter> _pump(WidgetTester tester) async {
  _dirty.value = true;
  _blockedOn.clear();
  Editor.confirm = false;
  final router = raku(
    initial: const Home(),
    routes: [
      tabs(
        shell: (context, tabs, child) {
          _tabs = tabs;
          return child;
        },
        branches: [
          [
            route(
              '/home',
              (_) => const Home(),
              (_) => const Text('home'),
              children: [
                route('edit', (_) => const Editor(), (_) => const Text('edit')),
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
    ],
  );
  addTearDown(() => (router.routerDelegate as ChangeNotifier).dispose());
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  await router.push(const Editor());
  await tester.pumpAndSettle();
  return router;
}

// What the browser does on back: report the previous URL.
Future<void> _browserTo(
  WidgetTester tester,
  RakuRouter router,
  String url,
) async {
  final route = await router.routeInformationParser!
      .parseRouteInformation(RouteInformation(uri: Uri.parse(url)));
  await router.routerDelegate.setNewRoutePath(route);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('browser back off a dirty editor is vetoed; URL snaps back',
      (tester) async {
    final reported = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.navigation,
      (call) async {
        if (call.method == 'routeInformationUpdated') {
          reported.add((call.arguments as Map)['uri'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.navigation, null),
    );
    final router = await _pump(tester);
    reported.clear();

    await _browserTo(tester, router, '/home');

    expect(find.text('edit'), findsOneWidget, reason: 'the page survived');
    expect(router.current.value, const Editor());
    expect(
      _blockedOn,
      [_tabs!.activeStack],
      reason: 'onPopBlocked ran once, '
          'with a context inside the guarded page\'s own stack',
    );
    expect(reported.last, '/home/edit', reason: 'address bar put back');
  });

  testWidgets('confirming in onPopBlocked pops the guarded page',
      (tester) async {
    final router = await _pump(tester);
    Editor.confirm = true;

    await _browserTo(tester, router, '/home');

    expect(find.text('home'), findsOneWidget);
    expect(router.current.value, const Home());
  });

  testWidgets('a clean editor lets the browser go back', (tester) async {
    final router = await _pump(tester);
    _dirty.value = false;

    await _browserTo(tester, router, '/home');

    expect(router.current.value, const Home());
    expect(_blockedOn, isEmpty);
  });

  testWidgets('switching tabs by URL keeps the guarded page — not blocked',
      (tester) async {
    final router = await _pump(tester);

    await _browserTo(tester, router, '/settings');

    expect(router.current.value, const Settings());
    expect(_blockedOn, isEmpty);
    expect(
      _tabs!.branches.first.stack.current,
      const Editor(),
      reason: 'the editor (and its unsaved state) is preserved in its tab',
    );
  });
}
