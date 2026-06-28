// A RouteGuard is honoured by the framework's pop machinery (PopScope): an
// imperative Navigator.pop is blocked while canPop is false, onPopBlocked fires,
// and rebuildOn re-evaluates canPop so the block can clear.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raku_router/raku_router.dart';

// Test-scoped guard state (reset in setUp).
final ValueNotifier<bool> _dirty = ValueNotifier<bool>(true);
int _blockedCount = 0;

class _Home extends RakuRoute {
  const _Home();
}

class _Editor extends RakuRoute with RouteGuard {
  const _Editor();

  @override
  bool get canPop => !_dirty.value;

  @override
  Listenable? get rebuildOn => _dirty;

  @override
  void onPopBlocked(BuildContext context) => _blockedCount++;
}

/// A guard that always blocks and relies on the default (no-op) onPopBlocked.
class _AlwaysBlock extends RakuRoute with RouteGuard {
  const _AlwaysBlock();
  @override
  bool get canPop => false;
}

Widget _screen(BuildContext context, RakuRoute route) =>
    Text(route is _Editor ? 'editor' : 'home');

void main() {
  setUp(() {
    _dirty.value = true;
    _blockedCount = 0;
  });

  testWidgets(
      'a guard blocks an imperative pop and fires onPopBlocked, then '
      'clears when rebuildOn changes', (tester) async {
    final stack = RouteStack(const _Home());
    await stack.push(const _Editor());
    addTearDown(stack.dispose);

    await tester.pumpWidget(
      MaterialApp(home: RouteStackView(stack: stack, builder: _screen)),
    );
    await tester.pumpAndSettle();
    expect(find.text('editor'), findsOneWidget);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator).last);

    // canPop is false (dirty) → the framework pop is blocked, guard is notified.
    await navigator.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('editor'), findsOneWidget, reason: 'blocked');
    expect(stack.length, 2);
    expect(_blockedCount, greaterThan(0), reason: 'onPopBlocked fired');

    // Clearing dirty re-evaluates canPop via rebuildOn → the pop now succeeds.
    _dirty.value = false;
    await tester.pumpAndSettle();
    await navigator.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget, reason: 'allowed after clearing');
    expect(stack.length, 1);
  });

  testWidgets('context.pop on a guarded route runs onPopBlocked, not a pop',
      (tester) async {
    final stack = RouteStack(const _Home());
    await stack.push(const _Editor());
    addTearDown(stack.dispose);
    late BuildContext editorContext;

    await tester.pumpWidget(
      MaterialApp(
        home: RouteStackView(
          stack: stack,
          builder: (context, route) {
            if (route is _Editor) editorContext = context;
            return _screen(context, route);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(await editorContext.pop(), isFalse, reason: 'blocked while dirty');
    expect(_blockedCount, greaterThan(0));
    expect(stack.length, 2);

    _dirty.value = false;
    expect(await editorContext.pop(), isTrue, reason: 'pops once clean');
    await tester.pumpAndSettle();
    expect(stack.length, 1);
  });

  testWidgets('the default onPopBlocked is a harmless no-op', (tester) async {
    final stack = RouteStack(const _Home());
    await stack.push(const _AlwaysBlock());
    addTearDown(stack.dispose);
    late BuildContext blockedContext;

    await tester.pumpWidget(
      MaterialApp(
        home: RouteStackView(
          stack: stack,
          builder: (context, route) {
            if (route is _AlwaysBlock) blockedContext = context;
            return const Text('x');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(await blockedContext.pop(), isFalse);
    expect(stack.length, 2);
  });
}
