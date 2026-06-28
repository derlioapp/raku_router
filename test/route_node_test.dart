// Tests for the route tree matcher — the web-grade core: a URL's path structure
// produces the navigation stack, tabs resolve recursively (active branch + its
// stack, others at their initial), and a full-page route stacks above the shell.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raku_router/raku_router.dart';

import 'fixtures.dart';

List<RakuRoute> _routes(List<RouteMatch> stack) =>
    [for (final m in stack) (m as ScreenMatch).route];

// A plain screen tree (no tabs).
RouteTree _screenTree() => RouteTree([
      route(
        '/feed',
        (_) => const Home(),
        (_) => const Text('feed'),
        children: [
          route(
            'notes/:id',
            (p) => Note(p('id')),
            (n) => Text('note-${n.id}'),
            transition: RakuTransitions.slide,
          ),
        ],
      ),
      route(
        '/photo/:id',
        (p) => FullScreen(p('id')),
        (_) => const Text('photo'),
      ),
    ]);

// A tabbed tree: tab 0 (Feed → Note), tab 1 (Settings), plus a full-page Photo.
RouteTree _tabbedTree() => RouteTree([
      tabs(
        shell: (context, controller, child) => child,
        branches: [
          [
            route(
              '/feed',
              (_) => const Home(),
              (_) => const Text('feed'),
              children: [
                route(
                  'notes/:id',
                  (p) => Note(p('id')),
                  (n) => Text('n${n.id}'),
                ),
              ],
            ),
          ],
          [route('/settings', (_) => const Plain(), (_) => const Text('set'))],
        ],
      ),
      route('/photo/:id', (p) => FullScreen(p('id')), (_) => const Text('p')),
    ]);

void main() {
  group('screen tree', () {
    final tree = _screenTree();

    test('a nested URL produces the full ancestor stack', () {
      expect(
        _routes(tree.match(Uri.parse('/feed/notes/42'))!),
        [const Home(), const Note('42')],
      );
    });

    test('a parent URL produces just that route', () {
      expect(_routes(tree.match(Uri.parse('/feed'))!), [const Home()]);
    });

    test('a top-level URL', () {
      expect(
        _routes(tree.match(Uri.parse('/photo/5'))!),
        [const FullScreen('5')],
      );
    });

    test('no match returns null', () {
      expect(tree.match(Uri.parse('/nope')), isNull);
    });

    test('query parameters reach parse', () {
      final t = RouteTree([
        route(
          '/s',
          (p) => Note(p.query('q') ?? 'none'),
          (_) => const Text('x'),
        ),
      ]);
      expect(_routes(t.match(Uri.parse('/s?q=hi'))!), [const Note('hi')]);
    });
  });

  group('tabs', () {
    final tree = _tabbedTree();

    test('a URL inside a tab resolves to the shell with that branch active',
        () {
      final shell = tree.match(Uri.parse('/settings'))!.single as TabsMatch;
      expect(shell.activeBranch, 1);
      expect(_routes(shell.branches[1]), [const Plain()]);
      // The inactive branch sits at its initial route.
      expect(_routes(shell.branches[0]), [const Home()]);
    });

    test('a nested URL reconstructs the active branch stack', () {
      final shell =
          tree.match(Uri.parse('/feed/notes/42'))!.single as TabsMatch;
      expect(shell.activeBranch, 0);
      expect(_routes(shell.branches[0]), [const Home(), const Note('42')]);
    });

    test('a full-page URL stacks above the shell (kept at its initials)', () {
      final stack = tree.match(Uri.parse('/photo/5'))!;
      expect(stack, hasLength(2));
      expect((stack.first as TabsMatch).activeBranch, 0);
      expect((stack.last as ScreenMatch).route, const FullScreen('5'));
    });

    test('locationOf works across tabs, nesting and full-page', () {
      expect(tree.locationOf(const Note('42')), Uri.parse('/feed/notes/42'));
      expect(tree.locationOf(const Plain()), Uri.parse('/settings'));
      expect(tree.locationOf(const FullScreen('5')), Uri.parse('/photo/5'));
    });
  });

  test('nested tabs resolve recursively', () {
    final tree = RouteTree([
      tabs(
        shell: (context, controller, child) => child,
        branches: [
          [
            tabs(
              shell: (context, controller, child) => child,
              branches: [
                [route('/a', (_) => const Home(), (_) => const Text('a'))],
                [route('/b', (_) => const Plain(), (_) => const Text('b'))],
              ],
            ),
          ],
          [route('/c', (_) => const FullScreen('c'), (_) => const Text('c'))],
        ],
      ),
    ]);

    final outer = tree.match(Uri.parse('/b'))!.single as TabsMatch;
    expect(outer.activeBranch, 0);
    final inner = outer.branches[0].single as TabsMatch;
    expect(inner.activeBranch, 1);
    expect((inner.branches[1].single as ScreenMatch).route, const Plain());
    // The outer's other branch sits at its initial (a screen).
    expect(
      (outer.branches[1].single as ScreenMatch).route,
      const FullScreen('c'),
    );

    // The other outer branch active → the nested tabs sits at its initial.
    final other = tree.match(Uri.parse('/c'))!.single as TabsMatch;
    expect(other.activeBranch, 1);
    expect((other.branches[0].single as TabsMatch).activeBranch, 0);
  });

  group('reverse & errors', () {
    test('handles reflects membership', () {
      final tree = _screenTree();
      expect(tree.handles(const Note('1')), isTrue);
      expect(tree.handles(const Plain()), isFalse);
    });

    testWidgets('screen and transitionFor resolve per node', (tester) async {
      final tree = _screenTree();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) => tree.screen(context, const Note('42')),
          ),
        ),
      );
      expect(find.text('note-42'), findsOneWidget);
      expect(tree.transitionFor(const Note('1')), RakuTransitions.slide);
      expect(tree.transitionFor(const Home()), isNull);
    });

    test('locationOf / transitionFor throw for an unknown route', () {
      final tree = _screenTree();
      expect(
        () => tree.locationOf(const Plain()),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => tree.transitionFor(const Plain()),
        throwsA(isA<AssertionError>()),
      );
    });

    test('a single-param node whose route lacks the prop is rejected', () {
      final tree = RouteTree([
        route('/x/:id', (_) => const Home(), (_) => const Text('x')),
      ]);
      expect(
        () => tree.locationOf(const Home()),
        throwsA(
          isA<AssertionError>().having(
            (e) => e.message,
            'm',
            contains('props'),
          ),
        ),
      );
    });

    test('a multi-param node without encode is rejected', () {
      final tree = RouteTree([
        route('/u/:a/:b', (_) => const Home(), (_) => const Text('x')),
      ]);
      expect(
        () => tree.locationOf(const Home()),
        throwsA(
          isA<AssertionError>().having(
            (e) => e.message,
            'm',
            contains('parameters'),
          ),
        ),
      );
    });

    test('more than one top-level tabs() shell is rejected loudly', () {
      RouteNode shell() => tabs(
            shell: (context, controller, child) => child,
            branches: [
              [route('/a', (_) => const Home(), (_) => const Text('a'))],
            ],
          );
      expect(
        () => RouteTree([shell(), shell()]),
        throwsA(
          isA<AssertionError>().having(
            (e) => e.message,
            'm',
            contains('at most one top-level tabs()'),
          ),
        ),
      );
    });

    test('encode builds a multi-param URL and round-trips with parse', () {
      final tree = RouteTree([
        route<Member>(
          '/orgs/:org/members/:id',
          (p) => Member(p('org'), p('id')),
          (_) => const Text('member'),
          encode: (m) => RoutePath({'org': m.org, 'id': m.id}),
        ),
      ]);

      const member = Member('acme', '42');
      final uri = tree.locationOf(member);
      expect(uri, Uri.parse('/orgs/acme/members/42'));
      // The match parses straight back to an equal route.
      expect((tree.match(uri)!.single as ScreenMatch).route, member);
    });

    test('encode appends query parameters (percent-encoded)', () {
      final tree = RouteTree([
        route<Search>(
          '/search',
          (p) => Search(p.query('q') ?? ''),
          (_) => const Text('search'),
          encode: (s) => RoutePath(const {}, query: {'q': s.term}),
        ),
      ]);

      final uri = tree.locationOf(const Search('hello world'));
      expect(uri.path, '/search');
      expect(uri.queryParameters['q'], 'hello world');
      expect(
        (tree.match(uri)!.single as ScreenMatch).route,
        const Search('hello world'),
      );
    });
  });
}

/// A two-parameter route — needs an explicit `encode:` to build its URL.
class Member extends RakuRoute {
  const Member(this.org, this.id);
  final String org;
  final String id;
  @override
  List<Object?> get props => [org, id];
}

/// A query-backed route — its state lives in `?q`, not the path.
class Search extends RakuRoute {
  const Search(this.term);
  final String term;
  @override
  List<Object?> get props => [term];
}
