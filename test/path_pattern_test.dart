// Unit tests for the PathPattern engine — the URL ⟷ params core that the
// declarative router is built on.
import 'package:flutter_test/flutter_test.dart';
import 'package:raku_router/src/router/path_pattern.dart';

void main() {
  group('parameters / hasParameters', () {
    test('a literal-only template has no parameters', () {
      final p = PathPattern('/notes');
      expect(p.hasParameters, isFalse);
      expect(p.parameters, isEmpty);
    });

    test('parameters are listed in order', () {
      final p = PathPattern('/users/:uid/posts/:pid');
      expect(p.hasParameters, isTrue);
      expect(p.parameters, ['uid', 'pid']);
    });
  });

  group('match', () {
    test('matches a literal path with an empty param map', () {
      expect(PathPattern('/notes').match('/notes'), isEmpty);
    });

    test('captures a single parameter', () {
      expect(PathPattern('/notes/:id').match('/notes/42'), {'id': '42'});
    });

    test('captures multiple parameters', () {
      expect(
        PathPattern('/users/:uid/posts/:pid').match('/users/7/posts/9'),
        {'uid': '7', 'pid': '9'},
      );
    });

    test('returns null on a literal mismatch', () {
      expect(PathPattern('/notes/:id').match('/memos/42'), isNull);
    });

    test('returns null on a segment-count mismatch', () {
      expect(PathPattern('/notes/:id').match('/notes'), isNull);
      expect(PathPattern('/notes').match('/notes/42'), isNull);
    });

    test('the root matches only the root', () {
      expect(PathPattern('/').match('/'), isEmpty);
      expect(PathPattern('/').match('/notes'), isNull);
    });

    test('ignores trailing slashes and the query string', () {
      final p = PathPattern('/notes/:id');
      expect(p.match('/notes/42/'), {'id': '42'});
      expect(p.match('/notes/42?ref=x'), {'id': '42'});
    });

    test('percent-decodes captured values', () {
      expect(
        PathPattern('/q/:term').match('/q/hello%20world'),
        {'term': 'hello world'},
      );
    });
  });

  group('fill', () {
    test('builds a literal path', () {
      expect(PathPattern('/notes').fill(const {}), '/notes');
    });

    test('substitutes parameters', () {
      expect(PathPattern('/notes/:id').fill({'id': '42'}), '/notes/42');
    });

    test('the root template fills to /', () {
      expect(PathPattern('/').fill(const {}), '/');
    });

    test('percent-encodes substituted values', () {
      expect(
        PathPattern('/q/:term').fill({'term': 'hello world'}),
        '/q/hello%20world',
      );
    });

    test('a missing required parameter trips a Raku assertion', () {
      expect(
        () => PathPattern('/notes/:id').fill(const {}),
        throwsA(
          isA<AssertionError>().having(
            (e) => e.message,
            'message',
            contains('Raku:'),
          ),
        ),
      );
    });
  });

  group('catch-all (*)', () {
    test('isCatchAll flags a trailing wildcard', () {
      expect(PathPattern('/feed/*').isCatchAll, isTrue);
      expect(PathPattern('/feed/:id').isCatchAll, isFalse);
      expect(PathPattern('*').isCatchAll, isTrue);
    });

    test('captures the remaining path under "*"', () {
      expect(PathPattern('/feed/*').match('/feed/a/b/c'), {'*': 'a/b/c'});
      expect(PathPattern('*').match('/anything/here'), {'*': 'anything/here'});
    });

    test('matches its bare prefix with an empty remainder', () {
      expect(PathPattern('/feed/*').match('/feed'), {'*': ''});
    });

    test('requires the fixed leading segments to match', () {
      expect(PathPattern('/feed/*').match('/settings/x'), isNull);
      expect(PathPattern('/feed/notes/*').match('/feed'), isNull);
    });

    test('mixes fixed params with the catch-all', () {
      expect(
        PathPattern('/u/:id/*').match('/u/7/a/b'),
        {'id': '7', '*': 'a/b'},
      );
    });

    test('round-trips a multi-segment remainder', () {
      final p = PathPattern('/feed/*');
      expect(p.fill({'*': 'a/b/c'}), '/feed/a/b/c');
      expect(p.fill(p.match('/feed/a/b/c')!), '/feed/a/b/c');
    });

    test('an empty remainder fills to the bare prefix', () {
      expect(PathPattern('/feed/*').fill({'*': ''}), '/feed');
      expect(PathPattern('*').fill({'*': ''}), '/');
    });

    test('percent round-trips each remainder segment', () {
      final p = PathPattern('/feed/*');
      expect(p.match('/feed/hello%20world/x'), {'*': 'hello world/x'});
      expect(p.fill({'*': 'hello world/x'}), '/feed/hello%20world/x');
    });

    test('a non-terminal catch-all trips an assertion', () {
      expect(() => PathPattern('/feed/*/edit'), throwsA(isA<AssertionError>()));
    });
  });

  test('match and fill round-trip', () {
    final p = PathPattern('/users/:uid/posts/:pid');
    final params = p.match('/users/7/posts/9')!;
    expect(p.fill(params), '/users/7/posts/9');
  });

  test('toString shows the template', () {
    expect(PathPattern('/notes/:id').toString(), 'PathPattern(/notes/:id)');
  });
}
