// A route's `title:` sets the browser tab / task-switcher label of the active
// leaf, via SystemChrome.setApplicationSwitcherDescription (the same platform
// call Flutter's Title widget uses). It is opt-in: with no titles declared, the
// platform is never touched.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raku_router/raku_router.dart';

class Feed extends RakuRoute {
  const Feed();
}

class Note extends RakuRoute {
  const Note(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

// Records the non-empty tab labels pushed to the platform. MaterialApp's own
// Title widget (default `title: ''`) also fires this call from above our router;
// filtering empties isolates the titles our router contributes (which, building
// deeper, win the effective document.title on each frame).
List<String> _spyOnTitles(WidgetTester tester) {
  final labels = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'SystemChrome.setApplicationSwitcherDescription') {
        final label = (call.arguments as Map)['label'] as String;
        if (label.isNotEmpty) labels.add(label);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return labels;
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
  testWidgets('the active leaf\'s title becomes the tab label', (tester) async {
    final labels = _spyOnTitles(tester);
    final config = raku(
      initial: const Feed(),
      routes: [
        route(
          '/feed',
          (_) => const Feed(),
          (_) => const Text('feed'),
          title: (_) => 'Feed',
          children: [
            route(
              'notes/:id',
              (p) => Note(p('id')),
              (n) => Text('note-${n.id}'),
              title: (n) => 'Note ${n.id}',
            ),
          ],
        ),
      ],
    );
    addTearDown(() => (config.routerDelegate as ChangeNotifier).dispose());

    await tester.pumpWidget(MaterialApp.router(routerConfig: config));
    await tester.pumpAndSettle();
    expect(labels, ['Feed'], reason: 'initial route title');

    await _go(tester, config, '/feed/notes/42');
    expect(labels, ['Feed', 'Note 42']);

    // Rebuilding on the same leaf does not re-hit the platform channel.
    (config.routerDelegate as ChangeNotifier).notifyListeners();
    await tester.pumpAndSettle();
    expect(labels, ['Feed', 'Note 42']);
  });

  testWidgets('no titles declared → the platform is never touched',
      (tester) async {
    final labels = _spyOnTitles(tester);
    final config = raku(
      initial: const Feed(),
      routes: [route('/feed', (_) => const Feed(), (_) => const Text('feed'))],
    );
    addTearDown(() => (config.routerDelegate as ChangeNotifier).dispose());

    await tester.pumpWidget(MaterialApp.router(routerConfig: config));
    await tester.pumpAndSettle();
    expect(labels, isEmpty);
  });
}
