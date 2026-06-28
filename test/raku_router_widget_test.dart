// End-to-end for a single-stack `raku(...)` (a screen tree with no tabs):
// URLs parse to typed routes, typed navigation updates the screen and the
// address bar (currentConfiguration → restore), and pages animate with the
// premium slide by default — overridable and disable-able.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raku_router/raku_router.dart';

import 'fixtures.dart';

// Home screen with a button that navigates with a typed object — no strings.
Widget _home(BuildContext context) => GestureDetector(
      onTap: () => context.push(const Note('42')),
      child: const Text('home'),
    );

RouterConfig<RakuRoute> _config({
  RakuRoute Function(Uri uri)? onUnknown,
  RouteTransitionsBuilder? transition,
}) =>
    raku(
      initial: const Home(),
      onUnknown: onUnknown,
      transition: transition,
      routes: [
        route('/', (_) => const Home(), (_) => const Builder(builder: _home)),
        route('/notes/:id', (p) => Note(p('id')), (n) => Text('note-${n.id}')),
      ],
    );

// Pushes /notes/42 and returns (mid-transition dx/dy, settled dx/dy) of the
// incoming screen so a test can tell whether (and how) it animated.
Future<({Offset mid, Offset settled})> _navigateAndSample(
  WidgetTester tester,
  RouterConfig<RakuRoute> config,
) async {
  await tester.pumpWidget(MaterialApp.router(routerConfig: config));
  await tester.pumpAndSettle();
  await tester.tap(find.text('home'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  final mid = tester.getTopLeft(find.text('note-42'));
  await tester.pumpAndSettle();
  final settled = tester.getTopLeft(find.text('note-42'));
  return (mid: mid, settled: settled);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses URLs to typed routes and restores them', () async {
    final config = _config();
    addTearDown(() => (config.routerDelegate as ChangeNotifier).dispose());
    final parser = config.routeInformationParser!;

    final parsed = await parser.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/notes/42')),
    );
    expect(parsed, const Note('42'));
    expect(
      parser.restoreRouteInformation(const Note('42'))?.uri,
      Uri.parse('/notes/42'),
    );
  });

  test('an unknown URL falls back through onUnknown', () async {
    final config = _config(onUnknown: (_) => const Plain());
    addTearDown(() => (config.routerDelegate as ChangeNotifier).dispose());
    final parser = config.routeInformationParser!;

    final parsed = await parser.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/does/not/exist')),
    );
    expect(parsed, const Plain());
  });

  test('the initial address is derived from the initial route', () {
    final config = _config();
    addTearDown(() => (config.routerDelegate as ChangeNotifier).dispose());
    expect(config.routeInformationProvider!.value.uri, Uri.parse('/'));
  });

  testWidgets('deep link renders, typed navigation updates screen + address', (
    tester,
  ) async {
    final config = _config();
    final delegate = config.routerDelegate;

    await tester.pumpWidget(MaterialApp.router(routerConfig: config));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);

    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();

    expect(find.text('note-42'), findsOneWidget);
    // Address bar follows: currentConfiguration → restore → /notes/42.
    expect(delegate.currentConfiguration, const Note('42'));
    expect(
      config.routeInformationParser!
          .restoreRouteInformation(delegate.currentConfiguration!)
          ?.uri,
      Uri.parse('/notes/42'),
    );
  });

  testWidgets('pages animate with the premium slide by default', (
    tester,
  ) async {
    final config = _config();
    addTearDown(() => (config.routerDelegate as ChangeNotifier).dispose());

    final s = await _navigateAndSample(tester, config);
    // Default slideIn(from: right) → the incoming screen slides in horizontally.
    expect(s.mid.dx, greaterThan(s.settled.dx), reason: 'slid from right');
  });

  testWidgets('the default animation can be disabled with none', (
    tester,
  ) async {
    final config = _config(transition: RakuTransitions.none);
    addTearDown(() => (config.routerDelegate as ChangeNotifier).dispose());

    final s = await _navigateAndSample(tester, config);
    // No transition → the screen is at its final position immediately.
    expect(s.mid, s.settled);
  });

  testWidgets('the default animation can be changed globally', (tester) async {
    final config = _config(
      transition: RakuTransitions.slideIn(from: SlideFrom.bottom),
    );
    addTearDown(() => (config.routerDelegate as ChangeNotifier).dispose());

    final s = await _navigateAndSample(tester, config);
    // from: bottom → the incoming screen slides up (vertical, not horizontal).
    expect(s.mid.dy, greaterThan(s.settled.dy), reason: 'slid up');
    expect(s.mid.dx, s.settled.dx, reason: 'no horizontal movement');
  });
}
