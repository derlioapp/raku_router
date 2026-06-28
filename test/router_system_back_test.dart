// In deep-link (Router) mode the nested navigators run with handleSystemBack:
// false, so the discrete platform back button is routed to the delegate's
// popRoute. A guarded leaf must veto it AND run onPopBlocked there — the same
// confirm hook that fires for a gesture or an in-app pop.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raku_router/raku_router.dart';

int _blocked = 0;

class _Home extends RakuRoute {
  const _Home();
}

class _Locked extends RakuRoute with RouteGuard {
  const _Locked();
  @override
  bool get canPop => false;
  @override
  void onPopBlocked(BuildContext context) => _blocked++;
}

// Deliver the real platform 'popRoute' message (a discrete system back press).
Future<void> _systemBack(WidgetTester tester) async {
  final message = const JSONMethodCodec().encodeMethodCall(
    const MethodCall('popRoute'),
  );
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    message,
    (_) {},
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a guarded leaf vetoes the system back button and confirms',
      (tester) async {
    _blocked = 0;
    final config = raku(
      initial: const _Home(),
      routes: [
        route(
          '/',
          (_) => const _Home(),
          (_) => const Text('home'),
          children: [
            route(
              'locked',
              (_) => const _Locked(),
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
      RouteInformation(uri: Uri.parse('/locked')),
    );
    await config.routerDelegate.setNewRoutePath(loc);
    await tester.pumpAndSettle();
    expect(find.text('locked'), findsOneWidget);

    await _systemBack(tester);

    // Blocked (still on locked) and the confirm hook ran.
    expect(find.text('locked'), findsOneWidget, reason: 'guard vetoed');
    expect(_blocked, 1, reason: 'onPopBlocked fired on the discrete back');
  });
}
