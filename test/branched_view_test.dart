// TST-02 (widget) — BranchedStackView renders the active branch, keeps every
// branch's Navigator alive, and RouteBranch.withStack / activeBranch work.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raku_router/raku_router.dart';

import 'fixtures.dart';

void main() {
  test('RouteBranch.withStack wraps an existing stack; activeBranch resolves',
      () {
    final shared = RouteStack(const Home());
    final tabs = BranchedRouteStack(
      branches: [
        RouteBranch.withStack(id: 'a', stack: shared),
        RouteBranch(id: 'b', initial: const Plain()),
      ],
    );
    addTearDown(tabs.dispose);

    expect(tabs.activeBranch.id, 'a');
    expect(tabs.activeBranch.stack, same(shared));
  });

  testWidgets('renders the active branch and preserves per-branch stacks',
      (tester) async {
    final tabs = BranchedRouteStack(
      branches: [
        RouteBranch(id: 'a', initial: const Home()),
        RouteBranch(id: 'b', initial: const Plain()),
      ],
    );
    addTearDown(tabs.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: BranchedStackView(controller: tabs, builder: buildScreen),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);

    await tabs.stackOf('a').push(const Note('1'));
    await tester.pumpAndSettle();
    expect(find.text('note-1'), findsOneWidget);

    tabs.index = 1;
    await tester.pumpAndSettle();
    expect(find.text('plain'), findsOneWidget);
    expect(find.text('note-1'), findsNothing, reason: 'branch a is offstage');

    tabs.index = 0;
    await tester.pumpAndSettle();
    expect(find.text('note-1'), findsOneWidget, reason: 'branch a preserved');
  });

  testWidgets(
      'a branch builds lazily on first visit, then is cached (never rebuilt by '
      'other-branch navigation or by switching tabs)', (tester) async {
    final builds = <String, int>{};
    Widget countingScreen(BuildContext context, RakuRoute route) {
      final label = switch (route as TestRoute) {
        Home() => 'home',
        Plain() => 'plain',
        Note(:final id) => 'note-$id',
        _ => '?',
      };
      builds[label] = (builds[label] ?? 0) + 1;
      return Text(label);
    }

    final tabs = BranchedRouteStack(
      branches: [
        RouteBranch(id: 'a', initial: const Home()),
        RouteBranch(id: 'b', initial: const Plain()),
      ],
    );
    addTearDown(tabs.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: BranchedStackView(controller: tabs, builder: countingScreen),
      ),
    );
    await tester.pumpAndSettle();
    // Only the active branch is built up front; branch B is lazy.
    expect(builds['home'], 1);
    expect(builds['plain'], isNull, reason: 'inactive branch B not built yet');

    // Navigate inside branch A. Branch B (never visited) is still not built.
    await tabs.stackOf('a').push(const Note('1'));
    await tester.pumpAndSettle();
    expect(builds['note-1'], 1);
    expect(
      builds['plain'],
      isNull,
      reason: 'B still not built (never visited)',
    );

    // Switch to branch B → it builds now, for the first time. Branch A screens
    // must NOT rebuild.
    final homeBuilds = builds['home'];
    final noteBuilds = builds['note-1'];
    tabs.index = 1;
    await tester.pumpAndSettle();
    expect(builds['plain'], 1, reason: 'B built lazily on first visit');
    expect(builds['home'], homeBuilds, reason: 'A not rebuilt on switch');
    expect(builds['note-1'], noteBuilds, reason: 'A not rebuilt on switch');

    // Switch back to A, then to B again: neither rebuilds (both cached).
    tabs.index = 0;
    await tester.pumpAndSettle();
    expect(builds['home'], homeBuilds, reason: 'A cached, not rebuilt');
    tabs.index = 1;
    await tester.pumpAndSettle();
    expect(builds['plain'], 1, reason: 'B cached, not rebuilt on revisit');
  });

  testWidgets('nested navigation animates only the body; the shell stays put',
      (tester) async {
    final tabs = BranchedRouteStack(
      branches: [RouteBranch(id: 'a', initial: const Home())],
    );
    addTearDown(tabs.dispose);

    const barKey = Key('bottom-bar');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // The tabs (each its own Navigator) live in the body...
          body: BranchedStackView(controller: tabs, builder: buildScreen),
          // ...the shell chrome lives outside it.
          bottomNavigationBar: const SizedBox(key: barKey, height: 50),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final barBefore = tester.getRect(find.byKey(barKey));

    // Push a nested route that slides (Sheet mixes in RouteTransition → slide).
    await tabs.stackOf('a').push(const Sheet());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80)); // mid-transition

    // The shell bar has not moved at all while the body is animating.
    expect(
      tester.getRect(find.byKey(barKey)),
      barBefore,
      reason: 'shell bar is fixed during nested navigation',
    );
    // The body content IS animating: the incoming screen is still sliding in.
    final sheetMidX = tester.getTopLeft(find.text('sheet')).dx;

    await tester.pumpAndSettle();
    final sheetSettledX = tester.getTopLeft(find.text('sheet')).dx;
    expect(
      sheetMidX,
      greaterThan(sheetSettledX),
      reason: 'the nested body content slid into place (it animated)',
    );
    // The shell bar is still exactly where it started.
    expect(tester.getRect(find.byKey(barKey)), barBefore);
  });

  testWidgets('a fixed side menu stays put while only the content animates',
      (tester) async {
    final tabs = BranchedRouteStack(
      branches: [RouteBranch(id: 'a', initial: const Home())],
    );
    addTearDown(tabs.dispose);

    const menuKey = Key('side-menu');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              // A fixed side menu (the shell) outside the content...
              const SizedBox(key: menuKey, width: 80, height: double.infinity),
              // ...and the content area, where the tab Navigator lives.
              Expanded(
                child:
                    BranchedStackView(controller: tabs, builder: buildScreen),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final menuBefore = tester.getRect(find.byKey(menuKey));

    await tabs.stackOf('a').push(const Sheet());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80)); // mid-transition

    // Side menu unmoved; content still sliding in.
    expect(
      tester.getRect(find.byKey(menuKey)),
      menuBefore,
      reason: 'the side menu is fixed during nested navigation',
    );
    final contentMidX = tester.getTopLeft(find.text('sheet')).dx;

    await tester.pumpAndSettle();
    expect(
      contentMidX,
      greaterThan(tester.getTopLeft(find.text('sheet')).dx),
      reason: 'only the content area animated',
    );
    expect(tester.getRect(find.byKey(menuKey)), menuBefore);
  });
}
