// URLs are untrusted input — the address bar, a deep link from another app, a
// QR code, a push payload. A malformed or unknown one must fall back to
// `onUnknown` (or a catch-all), never crash the app; `router.routeOf` never
// throws either. Also pins the URL matching rules (case, slashes, fragment,
// repeated query keys) so 1.0 has no undefined behaviour.
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raku_router/raku_router.dart';

enum Kind { a, b }

class Home extends RakuRoute {
  const Home();
}

class Item extends RakuRoute {
  const Item(this.id);
  final int id;
  @override
  List<Object?> get props => [id];
}

class Category extends RakuRoute {
  const Category(this.kind);
  final Kind kind;
  @override
  List<Object?> get props => [kind.name];
}

class Search extends RakuRoute {
  const Search(this.q);
  final String q;
  @override
  List<Object?> get props => [q];
}

class Lost extends RakuRoute {
  const Lost(this.path);
  final String path;
  @override
  List<Object?> get props => [path];
}

class Missing extends RakuRoute {
  const Missing();
}

RakuRouter _router({bool catchAll = false}) => raku(
      initial: const Home(),
      onUnknown: (_) => const Missing(),
      routes: [
        route(
          '/',
          (_) => const Home(),
          (_) => const SizedBox(),
          children: [
            // Strict parsers that throw on bad input — the common real-world case.
            route(
              'items/:id',
              (p) => Item(p.asInt('id')),
              (_) => const SizedBox(),
            ),
            route(
              'kinds/:kind',
              (p) => Category(Kind.values.byName(p('kind'))),
              (_) => const SizedBox(),
            ),
            route(
              'search',
              (p) => Search(p.query('q') ?? ''),
              (_) => const SizedBox(),
              encode: (s) => RoutePath(const {}, query: {'q': s.q}),
            ),
          ],
        ),
        if (catchAll) route('*', (p) => Lost(p.rest), (_) => const SizedBox()),
      ],
    );

Future<RakuRoute> _parse(RakuRouter router, Uri uri) =>
    router.routeInformationParser!
        .parseRouteInformation(RouteInformation(uri: uri));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a malformed deep link falls back instead of crashing', () {
    final router = _router();

    test('a parse that throws (int.parse) → onUnknown', () async {
      expect(await _parse(router, Uri.parse('/items/abc')), const Missing());
      expect(await _parse(router, Uri.parse('/items/7')), const Item(7));
    });

    test('a parse that throws an Error (enum byName) → onUnknown', () async {
      expect(await _parse(router, Uri.parse('/kinds/zzz')), const Missing());
      expect(
        await _parse(router, Uri.parse('/kinds/b')),
        const Category(Kind.b),
      );
    });

    test('invalid percent-encoding → onUnknown', () async {
      expect(
        await _parse(router, Uri(path: '/items/%E0%A4')),
        const Missing(),
      );
    });

    test('a catch-all catches malformed URLs too (kept raw)', () async {
      final withCatchAll = _router(catchAll: true);
      expect(
        await _parse(withCatchAll, Uri(path: '/nope/%E0%A4')),
        const Lost('nope/%E0%A4'),
      );
      expect(
        await _parse(withCatchAll, Uri.parse('/items/abc')),
        const Lost('items/abc'),
      );
    });

    test('fuzz: no generated URL makes the parser or routeOf throw', () async {
      final random = Random(42);
      const alphabet = 'abc/%:?#&=*.-_~ E0A4F9é/items/kinds/search';
      for (var i = 0; i < 2000; i++) {
        final raw = String.fromCharCodes([
          for (var j = 0; j < random.nextInt(24); j++)
            alphabet.codeUnitAt(random.nextInt(alphabet.length)),
        ]);
        final uri = Uri.tryParse(raw);
        if (uri == null) continue;
        await expectLater(_parse(router, uri), completes, reason: raw);
        expect(() => router.routeOf(uri), returnsNormally, reason: raw);
      }
    });
  });

  group('router.routeOf', () {
    final router = _router();

    test('resolves a known URL to its typed route', () {
      expect(router.routeOf(Uri.parse('/items/3')), const Item(3));
      expect(router.routeOf(Uri.parse('/search?q=x')), const Search('x'));
    });

    test('returns null for an unknown or malformed URL (no onUnknown)', () {
      expect(router.routeOf(Uri.parse('/nope')), isNull);
      expect(router.routeOf(Uri.parse('/items/abc')), isNull);
      expect(router.routeOf(Uri(path: '/items/%E0%A4')), isNull);
    });
  });

  group('URL matching rules (defined, not accidental)', () {
    final router = _router();

    test('a trailing slash and doubled slashes are ignored', () {
      expect(router.routeOf(Uri.parse('/items/1/')), const Item(1));
      expect(router.routeOf(Uri.parse('/items//1')), const Item(1));
    });

    test('matching is case-sensitive', () {
      expect(router.routeOf(Uri.parse('/ITEMS/1')), isNull);
    });

    test('the #fragment is ignored (and not round-tripped)', () {
      expect(router.routeOf(Uri.parse('/items/1#reviews')), const Item(1));
      expect(router.hrefOf(const Item(1)), '/items/1');
    });

    test('a repeated query key keeps its last value', () {
      expect(router.routeOf(Uri.parse('/search?q=a&q=b')), const Search('b'));
    });

    test('params are percent-decoded, and re-encoded on the way out', () {
      expect(
        router.routeOf(Uri.parse('/search?q=a%20b%2Fc')),
        const Search('a b/c'),
      );
      expect(
        router.routeOf(router.uriOf(const Search('a b/c'))),
        const Search('a b/c'),
      );
    });
  });
}
