// Tests for RouteParams — the read-only view of a matched URL's path `:params`
// and `?query` parameters, passed to a route's `parse` function.
import 'package:flutter_test/flutter_test.dart';
import 'package:raku_router/raku_router.dart';

void main() {
  group('RouteParams', () {
    test('call returns a present value; optional tolerates absence', () {
      final p = RouteParams({'id': '42'});
      expect(p('id'), '42');
      expect(p.optional('id'), '42');
      expect(p.optional('nope'), isNull);
    });

    test('call asserts on a missing required parameter', () {
      expect(() => RouteParams(const {})('id'), throwsA(isA<AssertionError>()));
    });

    test('asInt / optionalInt / query accessors', () {
      final p = RouteParams(const {'id': '42'}, const {'q': 'hi'});
      expect(p.asInt('id'), 42);
      expect(p.optionalInt('id'), 42);
      expect(p.optionalInt('missing'), isNull);
      expect(RouteParams(const {'x': 'abc'}).optionalInt('x'), isNull);
      expect(p.query('q'), 'hi');
      expect(p.query('none'), isNull);
    });
  });
}
