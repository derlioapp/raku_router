// API-04 — error & assertion contract: programmer errors assert in debug with
// a `Raku:`-prefixed message; control flow (guards) is not an error.
import 'package:flutter_test/flutter_test.dart';
import 'package:raku_router/raku_router.dart';

import 'fixtures.dart';

Matcher get _rakuAssertion => throwsA(
      isA<AssertionError>().having(
        (e) => e.message,
        'message',
        contains('Raku:'),
      ),
    );

void main() {
  test('an empty stack is rejected (fromRoutes / setRoutes)', () {
    expect(() => RouteStack.fromRoutes(const []), _rakuAssertion);

    final s = RouteStack(const Home());
    addTearDown(s.dispose);
    expect(() => s.setRoutes(const []), _rakuAssertion);
  });

  test('a branched stack needs at least one branch', () {
    expect(() => BranchedRouteStack(branches: const []), _rakuAssertion);
  });

  test('an out-of-range initialIndex is rejected', () {
    expect(
      () => BranchedRouteStack(
        branches: [RouteBranch(id: 'a', initial: const Home())],
        initialIndex: 5,
      ),
      _rakuAssertion,
    );
  });

  test('an out-of-range branch index is rejected', () {
    final tabs = BranchedRouteStack(
      branches: [RouteBranch(id: 'a', initial: const Home())],
    );
    addTearDown(tabs.dispose);
    expect(() => tabs.index = 3, _rakuAssertion);
  });

  test('a vetoed pop is control flow, not an error', () async {
    final s = RouteStack(const Home());
    await s.push(const Guarded(allow: false));
    expect(await s.pop(), isFalse); // returns false, never throws
    expect(s.length, 2);
  });
}
