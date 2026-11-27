import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raku_router/raku_router.dart';

void main() {
  Future<void> pumpRiseUp(
    WidgetTester tester, {
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
  }) {
    return tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (BuildContext context) => RakuTransitions.riseUp(
            context,
            animation,
            secondaryAnimation,
            const Text('PAGE'),
          ),
        ),
      ),
    );
  }

  testWidgets('entering page is painted and offset upward', (tester) async {
    final AnimationController c = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 300),
    );
    addTearDown(c.dispose);
    c.value = 0.5; // mid-way, default (forward) direction → entering

    await pumpRiseUp(
      tester,
      animation: c,
      secondaryAnimation: kAlwaysDismissedAnimation,
    );

    expect(find.text('PAGE'), findsOneWidget);
    final Transform xf = tester.widget<Transform>(find.byType(Transform));
    // Mid-rise: still translated down toward its 12px start, not yet settled.
    expect(xf.transform.getTranslation().y, greaterThan(0));
  });

  testWidgets('leaving (popping) page is hidden — no overlap', (tester) async {
    final AnimationController c = AnimationController(
      vsync: tester,
      value: 1,
      duration: const Duration(milliseconds: 300),
    );
    addTearDown(c.dispose);
    c.reverse(); // status == reverse → this page is leaving

    await pumpRiseUp(
      tester,
      animation: c,
      secondaryAnimation: kAlwaysDismissedAnimation,
    );
    c.stop(); // freeze the ticker; the reverse-status frame is already built

    // The leaving page paints nothing, so two pages never stack mid-transition.
    expect(find.text('PAGE'), findsNothing);
    expect(find.byType(Transform), findsNothing);
  });

  testWidgets('covered page is hidden', (tester) async {
    final AnimationController covered = AnimationController(
      vsync: tester,
      value: 0.3, // something is rising over this page
      duration: const Duration(milliseconds: 300),
    );
    addTearDown(covered.dispose);

    await pumpRiseUp(
      tester,
      animation: kAlwaysCompleteAnimation, // this page is fully presented…
      secondaryAnimation: covered, // …but covered by an incoming page
    );

    expect(find.text('PAGE'), findsNothing);
  });
}
