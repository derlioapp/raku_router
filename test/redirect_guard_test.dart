// TST-03 — redirect & guard depth: sync/async redirects, chains, the
// sameDestination short-circuit, loop detection (assert-aware), guard veto.
import 'package:flutter_test/flutter_test.dart';
import 'package:raku_router/raku_router.dart';

import 'fixtures.dart';

void main() {
  test('a synchronous redirect resolves on push', () async {
    final s = RouteStack(const Home());
    await s.push(const Legacy()); // → Home
    expect(s.current, const Home());
    expect(s.length, 2);
  });

  test('redirect chains are followed to the end', () async {
    final s = RouteStack(const Home());
    await s.push(const LegacyChain()); // → Legacy → Home
    expect(s.current, const Home());
  });

  test('asynchronous redirects are awaited', () async {
    final s = RouteStack(const Home());
    await s.push(const AsyncRedirect()); // awaits, then → Home
    expect(s.current, const Home());
  });

  test('a self-redirect stays put (sameDestination short-circuit)', () async {
    final s = RouteStack(const Home());
    await s.push(const SelfRedirect());
    expect(s.current, const SelfRedirect());
    expect(s.length, 2);
  });

  test('redirects also run on replace', () async {
    final s = RouteStack(const Home());
    await s.push(const Plain());
    await s.replace(const Legacy()); // → Home
    expect(s.current, const Home());
    expect(s.length, 2);
  });

  test('redirect loops are detected and do not hang', () async {
    final s = RouteStack(const Home());
    // In debug the loop guard trips an assert rather than spinning forever.
    await expectLater(s.push(const LoopA()), throwsAssertionError);
  });

  test('a guard blocks pop, then allows it after replace', () async {
    final s = RouteStack(const Home());
    await s.push(const Guarded(allow: false));
    expect(await s.pop(), isFalse);
    expect(s.length, 2);

    await s.replace(const Guarded(allow: true));
    expect(await s.pop(), isTrue);
    expect(s.length, 1);
  });
}
