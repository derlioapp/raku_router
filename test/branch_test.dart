// TST-02 — branched navigation: per-branch back stacks, index setter, stackOf,
// listener fan-out, and dispose detaching inner-stack listeners.
import 'package:flutter_test/flutter_test.dart';
import 'package:raku_router/raku_router.dart';

import 'fixtures.dart';

void main() {
  BranchedRouteStack build() => BranchedRouteStack(
        branches: [
          RouteBranch(id: 'a', initial: const Home()),
          RouteBranch(id: 'b', initial: const Plain()),
        ],
      );

  test('per-branch back stacks survive tab switches', () async {
    final tabs = build();
    addTearDown(tabs.dispose);

    await tabs.stackOf('a').push(const Note('1'));
    expect(tabs.activeStack.length, 2, reason: 'branch a is active (index 0)');

    tabs.index = 1;
    expect(tabs.index, 1);
    expect(tabs.activeStack.length, 1, reason: 'branch b is untouched');

    tabs.index = 0;
    expect(tabs.activeStack.length, 2, reason: 'branch a stack preserved');
    expect(tabs.activeStack.current, const Note('1'));
  });

  test('index setter validates range and no-ops on the same value', () {
    final tabs = build();
    addTearDown(tabs.dispose);
    var notifications = 0;
    tabs.addListener(() => notifications++);

    tabs.index = 0; // same value → no notification
    expect(notifications, 0);

    tabs.index = 1; // genuine change → one notification
    expect(notifications, 1);

    expect(() => tabs.index = 5, throwsAssertionError);
  });

  test('stackOf returns the addressed branch stack', () {
    final tabs = build();
    addTearDown(tabs.dispose);
    expect(tabs.stackOf('a'), same(tabs.branches[0].stack));
    expect(tabs.stackOf('b'), same(tabs.branches[1].stack));
  });

  test('listeners fan out from inner-stack changes', () async {
    final tabs = build();
    addTearDown(tabs.dispose);
    var notifications = 0;
    tabs.addListener(() => notifications++);

    // A change on a *non-active* branch still notifies the shell.
    await tabs.stackOf('b').push(const Home());
    expect(notifications, 1);
  });

  test('dispose detaches inner-stack listeners (no leak)', () async {
    final tabs = build();
    var notifications = 0;
    tabs.addListener(() => notifications++);
    final stackA = tabs.stackOf('a');

    tabs.dispose(); // detaches the shell from every branch stack

    await stackA.push(const Note('x'));
    expect(notifications, 0, reason: 'detached: the shell no longer fires');
  });
}
