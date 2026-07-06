// context.replaceSilently updates the address bar without a new browser history
// entry — it wraps Router.neglect, which works with raku's delegate because the
// delegate implements currentConfiguration / restoreRouteInformation. We verify
// the actual `replace` flag sent to the platform: false for a push, true for a
// silent replace.
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

void main() {
  testWidgets('push adds history; replaceSilently updates in place',
      (tester) async {
    final uris = <String>[];
    final replaceFlags = <bool>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.navigation,
      (call) async {
        if (call.method == 'routeInformationUpdated') {
          final args = call.arguments as Map;
          uris.add((args['uri'] ?? args['location']) as String);
          replaceFlags.add(args['replace'] as bool);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.navigation, null),
    );

    final config = raku(
      initial: const Feed(),
      routes: [
        route(
          '/feed',
          (_) => const Feed(),
          (_) => const Text('feed'),
          children: [
            route(
              'notes/:id',
              (p) => Note(p('id')),
              (n) => Text('note-${n.id}'),
            ),
          ],
        ),
      ],
    );
    addTearDown(() => (config.routerDelegate as ChangeNotifier).dispose());

    await tester.pumpWidget(MaterialApp.router(routerConfig: config));
    await tester.pumpAndSettle();
    final context = tester.element(find.text('feed'));

    // A normal push reports the new URL and adds a history entry (replace:false).
    uris.clear();
    replaceFlags.clear();
    context.push(const Note('1'));
    await tester.pumpAndSettle();
    expect(uris.last, '/feed/notes/1');
    expect(replaceFlags.last, isFalse);

    // A silent replace reports the URL but in place (replace:true).
    uris.clear();
    replaceFlags.clear();
    context.replaceSilently(const Note('2'));
    await tester.pumpAndSettle();
    expect(find.text('note-2'), findsOneWidget);
    expect(uris.last, '/feed/notes/2');
    expect(replaceFlags.last, isTrue);
  });

  testWidgets('outside a Router, replaceSilently degrades to a plain replace',
      (tester) async {
    // A bare RouteStackView (no MaterialApp.router) provides a RouteStackScope
    // but no enclosing Router — so there is no URL to neglect and the call must
    // fall back to a normal replace on the stack.
    final stack = RouteStack(const Feed());
    addTearDown(stack.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: RouteStackView(
          stack: stack,
          builder: (context, route) => switch (route) {
            Note(:final id) => Text('note-$id'),
            _ => const Text('feed'),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('feed'), findsOneWidget);

    final context = tester.element(find.text('feed'));
    context.replaceSilently(const Note('9'));
    await tester.pumpAndSettle();

    expect(find.text('note-9'), findsOneWidget);
    expect(stack.value, [const Note('9')]);
  });
}
