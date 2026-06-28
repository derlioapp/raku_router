import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raku_router/raku_router.dart';

sealed class R extends RakuRoute {
  const R();
}

class A extends R {
  const A();
}

class B extends R {
  const B();
}

class P extends R {
  const P(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class Guarded extends R with RouteGuard {
  const Guarded({required this.allow});
  final bool allow;
  @override
  bool get canPop => allow;
}

class Legacy extends R with RouteRedirect {
  const Legacy();
  @override
  RakuRoute redirect() => const A();
}

class Loop extends R with RouteRedirect {
  const Loop();
  @override
  RakuRoute redirect() => const Loop2();
}

class Loop2 extends R with RouteRedirect {
  const Loop2();
  @override
  RakuRoute redirect() => const Loop();
}

void main() {
  test('push then pop', () async {
    final s = RouteStack(const A());
    expect(s.length, 1);
    expect(s.canPop, isFalse);

    await s.push(const B());
    expect(s.length, 2);
    expect(s.current, isA<B>());

    expect(await s.pop(), isTrue);
    expect(s.current, isA<A>());
    expect(await s.pop(), isFalse); // never pops the root
  });

  test('guard blocks pop, then allows it', () async {
    final s = RouteStack(const A());
    await s.push(const Guarded(allow: false));
    expect(await s.pop(), isFalse);
    expect(s.length, 2);

    await s.replace(const Guarded(allow: true));
    expect(await s.pop(), isTrue);
    expect(s.length, 1);
  });

  test('redirect resolves on push', () async {
    final s = RouteStack(const A());
    await s.push(const Legacy());
    expect(s.current, isA<A>());
    expect(s.length, 2);
  });

  // Redirect-loop detection is covered (un-skipped) in redirect_guard_test.dart.

  test('popUntil stops at predicate', () async {
    final s = RouteStack(const A());
    await s.push(const P('1'));
    await s.push(const P('2'));
    expect(s.length, 3);

    s.popUntil((r) => r is A);
    expect(s.length, 1);
    expect(s.current, isA<A>());
  });

  test('reset to the route you are already on is a no-op', () async {
    final s = RouteStack(const P('1'));
    final entryId = s.entries.single.id;
    var notifications = 0;
    s.addListener(() => notifications++);

    s.reset(const P('1')); // same destination, single-entry stack
    expect(notifications, 0, reason: 'no rebuild when already there');
    expect(s.entries.single.id, entryId, reason: 'entry (and its page) reused');

    s.reset(const P('2')); // a genuinely different route still re-roots
    expect(notifications, 1);
    expect(s.current, const P('2'));
  });

  test('reset collapses a deep stack even onto the current top', () async {
    final s = RouteStack(const A());
    await s.push(const P('1'));
    expect(s.length, 2);

    // Top is P('1'); re-rooting there is NOT a no-op — it drops the deeper
    // entries (the sidebar "go to the folder I'm already inside" case).
    s.reset(const P('1'));
    expect(s.length, 1);
    expect(s.current, const P('1'));
  });

  test('sameDestination uses props', () {
    expect(const P('1').sameDestination(const P('1')), isTrue);
    expect(const P('1').sameDestination(const P('2')), isFalse);
    expect(const A().sameDestination(const A()), isTrue);
    expect(const A().sameDestination(const B()), isFalse);
  });

  test('value equality from (runtimeType, props)', () {
    // Build via a runtime value so the instances can't be const-canonicalised —
    // this proves *value* equality of genuinely distinct objects.
    final id = 1.toString();
    final p1 = P(id);
    final p1b = P(id);
    expect(identical(p1, p1b), isFalse, reason: 'genuinely distinct instances');
    expect(p1, p1b, reason: 'but value-equal via ==');
    expect(p1.hashCode, p1b.hashCode, reason: 'equal objects, equal hashCodes');

    expect(p1 == const P('2'), isFalse, reason: 'different props differ');
    expect(const A() == const A(), isTrue);
    expect(const A() == const B(), isFalse, reason: 'different runtimeType');

    // sameDestination is now just a readable alias of ==.
    expect(p1.sameDestination(p1b), p1 == p1b);
  });

  testWidgets('renders top route and reacts to push/pop', (tester) async {
    final s = RouteStack(const A());
    await tester.pumpWidget(
      MaterialApp(
        home: RouteStackView(
          stack: s,
          builder: (context, route) => switch (route as R) {
            A() => const Text('screen-A'),
            B() => const Text('screen-B'),
            P(:final id) => Text('screen-P$id'),
            Guarded() => const Text('screen-G'),
            Legacy() => const Text('screen-L'),
            Loop() => const Text('screen-loop'),
            Loop2() => const Text('screen-loop2'),
          },
        ),
      ),
    );

    expect(find.text('screen-A'), findsOneWidget);

    await s.push(const B());
    await tester.pumpAndSettle();
    expect(find.text('screen-B'), findsOneWidget);

    await s.pop();
    await tester.pumpAndSettle();
    expect(find.text('screen-A'), findsOneWidget);
  });
}
