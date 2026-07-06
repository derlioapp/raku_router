// RakuRouter.uriOf / hrefOf expose the route → URL direction of the tree, so a
// typed route can become a share link, deep link, or <a href>.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raku_router/raku_router.dart';

class Home extends RakuRoute {
  const Home();
}

class Note extends RakuRoute {
  const Note(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class Search extends RakuRoute {
  const Search(this.term);
  final String term;
  @override
  List<Object?> get props => [term];
}

RakuRouter _config() => raku(
      initial: const Home(),
      routes: [
        route(
          '/feed',
          (_) => const Home(),
          (_) => const Text('feed'),
          children: [
            route('notes/:id', (p) => Note(p('id')), (n) => Text('n-${n.id}')),
          ],
        ),
        route(
          '/search',
          (p) => Search(p.query('q') ?? ''),
          (s) => Text('s-${s.term}'),
          encode: (s) => RoutePath(const {}, query: {'q': s.term}),
        ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hrefOf builds a route\'s URL string', () {
    final router = _config();
    addTearDown(() => (router.routerDelegate as ChangeNotifier).dispose());

    expect(router.hrefOf(const Home()), '/feed');
    expect(router.hrefOf(const Note('42')), '/feed/notes/42');
  });

  test('uriOf returns a Uri, query state included', () {
    final router = _config();
    addTearDown(() => (router.routerDelegate as ChangeNotifier).dispose());

    expect(router.uriOf(const Note('42')), Uri.parse('/feed/notes/42'));
    expect(router.uriOf(const Search('shoes')), Uri.parse('/search?q=shoes'));
  });

  test('hrefOf and the URL parser round-trip', () async {
    final router = _config();
    addTearDown(() => (router.routerDelegate as ChangeNotifier).dispose());

    final href = router.hrefOf(const Note('7'));
    final parsed = await router.routeInformationParser!.parseRouteInformation(
      RouteInformation(uri: Uri.parse(href)),
    );
    expect(parsed, const Note('7'));
  });
}
