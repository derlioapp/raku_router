// Requests from apps dogfooding 0.3.0: RakuRouter.dispose, a router-wide
// pageBuilder, paused tickers in hidden tabs, reduce-motion-aware transitions,
// and a handled (not app-closing) system back when a guard vetoes it — which is
// what lets a tab's root page switch to the first tab instead of exiting.
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raku_router/raku_router.dart';

class _Home extends RakuRoute {
  const _Home();
}

class _Other extends RakuRoute {
  const _Other();
}

class _Styled extends RakuRoute {
  const _Styled();
}

// The second tab's root: back on it goes to the first tab (Material's rule)
// instead of closing the app.
class _SecondRoot extends RakuRoute with RouteGuard {
  const _SecondRoot();
  @override
  bool get canPop => false;
  @override
  void onPopBlocked(BuildContext context) => context.go(const _Home());
}

class _MyPage extends Page<Object?> {
  const _MyPage({required this.child, super.key, super.name});
  final Widget child;
  @override
  Route<Object?> createRoute(BuildContext context) => PageRouteBuilder<Object?>(
        settings: this,
        pageBuilder: (_, __, ___) => child,
      );
}

// Ticks counted by the second tab's endless animation.
int _ticks = 0;

class _Spinner extends StatefulWidget {
  const _Spinner();
  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )
      ..addListener(() => _ticks++)
      ..repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Text('second');
}

RakuRouter _tabsRouter({RakuPageBuilder? pageBuilder}) => raku(
      initial: const _Home(),
      pageBuilder: pageBuilder,
      routes: [
        tabs(
          shell: (_, __, child) => child,
          branches: [
            [route('/home', (_) => const _Home(), (_) => const Text('home'))],
            [
              route(
                '/second',
                (_) => const _SecondRoot(),
                (_) => const _Spinner(),
              ),
            ],
          ],
        ),
        route('/other', (_) => const _Other(), (_) => const Text('other')),
        route(
          '/styled',
          (_) => const _Styled(),
          (_) => const Text('styled'),
          transition: RakuTransitions.fade,
        ),
      ],
    );

Widget _app(RakuRouter router) => WidgetsApp.router(
      routerConfig: router,
      color: const Color(0xFF000000),
    );

Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  // Not pumpAndSettle: the second tab's spinner animates forever while shown.
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('RakuRouter.dispose releases the delegate and its notifiers',
      (tester) async {
    final router = _tabsRouter();
    await tester.pumpWidget(_app(router));
    await tester.pumpWidget(const SizedBox()); // the app using it is gone
    router.dispose();
    expect(() => router.current.addListener(() {}), throwsFlutterError);
  });

  testWidgets('raku(pageBuilder:) builds root and tab pages; transition: wins',
      (tester) async {
    final router = _tabsRouter(
      pageBuilder: (child, key, name) =>
          _MyPage(key: key, name: name, child: child),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    Iterable<Page<Object?>> pages() => tester
        .widgetList<Navigator>(find.byType(Navigator))
        .expand((n) => n.pages);

    // The root page (the shell) and the tab's page both use the app's page.
    expect(pages(), isNotEmpty);
    expect(pages().every((p) => p is _MyPage), isTrue);

    await router.push(const _Styled());
    await tester.pumpAndSettle();
    expect(find.text('styled'), findsOneWidget);
    // A route's own `transition:` is more specific than the global factory.
    expect(pages().whereType<RakuPage<Object?>>(), hasLength(1));
  });

  testWidgets('a hidden tab branch runs with tickers disabled', (tester) async {
    final router = _tabsRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    await router.go(const _SecondRoot());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // let the switch settle
    _ticks = 0;
    await tester.pump(const Duration(milliseconds: 100));
    expect(_ticks, greaterThan(0), reason: 'the visible tab animates');

    await router.go(const _Home());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    _ticks = 0;
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    // Still alive (state kept), but its animation no longer ticks.
    expect(find.text('second', skipOffstage: false), findsOneWidget);
    expect(_ticks, 0, reason: 'the hidden tab is muted');
  });

  group('reduce motion', () {
    Future<Widget> transitioned(
      WidgetTester tester,
      RouteTransitionsBuilder builder, {
      required bool disableAnimations,
    }) async {
      late Widget built;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (context) => built = builder(
                context,
                const AlwaysStoppedAnimation<double>(0.5),
                kAlwaysDismissedAnimation,
                const Text('page'),
              ),
            ),
          ),
        ),
      );
      return built;
    }

    final moving = <String, RouteTransitionsBuilder>{
      'slideIn': RakuTransitions.slideIn(),
      'slide': RakuTransitions.slide,
      'riseUp': RakuTransitions.riseUp,
    };
    for (final MapEntry(key: name, value: builder) in moving.entries) {
      testWidgets('$name cross-fades when animations are disabled',
          (tester) async {
        final reduced =
            await transitioned(tester, builder, disableAnimations: true);
        expect(reduced, isA<FadeTransition>());
        expect(find.byType(SlideTransition), findsNothing);

        final normal =
            await transitioned(tester, builder, disableAnimations: false);
        expect(normal, isNot(isA<FadeTransition>()));
      });
    }
  });

  testWidgets('back on a guarded tab root is handled: switches tab, app stays',
      (tester) async {
    var exits = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemNavigator.pop') exits++;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final router = _tabsRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();
    await router.go(const _SecondRoot());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(router.current.value, const _SecondRoot());

    await _systemBack(tester);

    expect(router.current.value, const _Home(), reason: 'went to first tab');
    expect(exits, 0, reason: 'a vetoed back must not close the app');
  });
}
