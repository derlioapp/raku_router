// A deep link rebuilds the whole ancestor chain, so a RouteRedirect on any route
// along it applies — not just the leaf's. Protecting a section root (`/admin`)
// protects every URL below it (`/admin/users/1`), and the same holds for
// `router.go`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raku_router/raku_router.dart';

bool _signedIn = false;

class Home extends RakuRoute {
  const Home();
}

class Login extends RakuRoute {
  const Login();
}

class Admin extends RakuRoute with RouteRedirect {
  const Admin();
  @override
  RakuRoute? redirect() => _signedIn ? null : const Login();
}

class User extends RakuRoute {
  const User(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

/// Half of a loop that only shows up across ancestors: Ping's child sends you
/// to Pong, whose *parent* sends you back under Ping.
class Ping extends RakuRoute with RouteRedirect {
  const Ping();
  @override
  RakuRoute? redirect() => const PongChild();
}

class PingChild extends RakuRoute {
  const PingChild();
}

class Pong extends RakuRoute with RouteRedirect {
  const Pong();
  @override
  RakuRoute? redirect() => const PingChild();
}

class PongChild extends RakuRoute {
  const PongChild();
}

Future<RakuRouter> _pump(WidgetTester tester) async {
  final router = raku(
    initial: const Home(),
    routes: [
      route('/', (_) => const Home(), (_) => const Text('home')),
      route('/login', (_) => const Login(), (_) => const Text('login')),
      route(
        '/admin',
        (_) => const Admin(),
        (_) => const Text('admin'),
        children: [
          route('users/:id', (p) => User(p('id')), (u) => Text('user-${u.id}')),
        ],
      ),
      route(
        '/ping',
        (_) => const Ping(),
        (_) => const Text('ping'),
        children: [
          route('child', (_) => const PingChild(), (_) => const Text('pc')),
        ],
      ),
      route(
        '/pong',
        (_) => const Pong(),
        (_) => const Text('pong'),
        children: [
          route('child', (_) => const PongChild(), (_) => const Text('qc')),
        ],
      ),
    ],
  );
  addTearDown(() => (router.routerDelegate as ChangeNotifier).dispose());
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

Future<void> _deepLink(
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
  setUp(() => _signedIn = false);

  testWidgets('a deep link below a protected section is redirected',
      (tester) async {
    final router = await _pump(tester);
    await _deepLink(tester, router, '/admin/users/1');

    expect(router.current.value, const Login());
    expect(find.text('user-1', skipOffstage: false), findsNothing);
    expect(find.text('admin', skipOffstage: false), findsNothing);
  });

  testWidgets('router.go below a protected section is redirected too',
      (tester) async {
    final router = await _pump(tester);
    await router.go(const User('1'));
    await tester.pumpAndSettle();
    expect(router.current.value, const Login());
  });

  testWidgets('when the ancestor lets you through, the link opens',
      (tester) async {
    _signedIn = true;
    final router = await _pump(tester);
    await _deepLink(tester, router, '/admin/users/1');

    expect(router.current.value, const User('1'));
    expect(await router.routerDelegate.popRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(router.current.value, const Admin(), reason: 'ancestor kept');
  });

  testWidgets('a loop across ancestors is detected (asserts in debug)',
      (tester) async {
    final router = await _pump(tester);
    await expectLater(
      router.go(const PingChild()),
      throwsA(
        isA<AssertionError>().having(
          (e) => e.message,
          'message',
          contains('Raku: redirect loop'),
        ),
      ),
    );
  });
}
