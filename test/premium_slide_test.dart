// Tests for the premium, direction-parametric slide (RakuTransitions.slideIn):
// the incoming page slides from the chosen edge, the covered page parallaxes and
// dims, and fade/dim are toggleable.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raku_router/raku_router.dart';

void main() {
  const pageKey = Key('page');

  Future<void> pumpSlide(
    WidgetTester tester,
    RouteTransitionsBuilder builder, {
    required Animation<double> animation,
    required Animation<double> secondary,
  }) {
    return tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            height: 200,
            child: Builder(
              builder: (context) => builder(
                context,
                animation,
                secondary,
                const SizedBox.expand(key: pageKey),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('the incoming page slides in from the parametric edge',
      (tester) async {
    final cases = <SlideFrom, bool Function(Offset rest, Offset mid)>{
      SlideFrom.right: (rest, mid) => mid.dx > rest.dx,
      SlideFrom.left: (rest, mid) => mid.dx < rest.dx,
      SlideFrom.top: (rest, mid) => mid.dy < rest.dy,
      SlideFrom.bottom: (rest, mid) => mid.dy > rest.dy,
    };

    for (final entry in cases.entries) {
      final builder =
          RakuTransitions.slideIn(from: entry.key, fade: false, dim: false);

      await pumpSlide(
        tester,
        builder,
        animation: kAlwaysCompleteAnimation,
        secondary: kAlwaysDismissedAnimation,
      );
      final rest = tester.getTopLeft(find.byKey(pageKey));

      await pumpSlide(
        tester,
        builder,
        animation: const AlwaysStoppedAnimation<double>(0.5),
        secondary: kAlwaysDismissedAnimation,
      );
      final mid = tester.getTopLeft(find.byKey(pageKey));

      expect(entry.value(rest, mid), isTrue, reason: 'from ${entry.key}');
    }
  });

  testWidgets('the incoming page fades through', (tester) async {
    final builder = RakuTransitions.slideIn(dim: false); // fade on

    await pumpSlide(
      tester,
      builder,
      animation: const AlwaysStoppedAnimation<double>(0.2),
      secondary: kAlwaysDismissedAnimation,
    );
    expect(
      tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value,
      lessThan(1),
    );

    await pumpSlide(
      tester,
      builder,
      animation: kAlwaysCompleteAnimation,
      secondary: kAlwaysDismissedAnimation,
    );
    expect(
      tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value,
      1,
    );
  });

  testWidgets('the covered page parallaxes in the travel direction and dims',
      (tester) async {
    final builder = RakuTransitions.slideIn(); // from right, dim on

    await pumpSlide(
      tester,
      builder,
      animation: kAlwaysCompleteAnimation,
      secondary: kAlwaysDismissedAnimation,
    );
    final rest = tester.getTopLeft(find.byKey(pageKey));

    await pumpSlide(
      tester,
      builder,
      animation: kAlwaysCompleteAnimation,
      secondary: const AlwaysStoppedAnimation<double>(0.5),
    );
    final covered = tester.getTopLeft(find.byKey(pageKey));

    // From the right → the outgoing page recedes left.
    expect(covered.dx, lessThan(rest.dx), reason: 'parallax');
    // The dim scrim is present and visible.
    final dim = tester.widget<FadeTransition>(
      find.ancestor(
        of: find.byType(ColoredBox),
        matching: find.byType(FadeTransition),
      ),
    );
    expect(dim.opacity.value, greaterThan(0));
  });

  testWidgets('fade and dim can be turned off', (tester) async {
    await pumpSlide(
      tester,
      RakuTransitions.slideIn(fade: false, dim: false),
      animation: const AlwaysStoppedAnimation<double>(0.5),
      secondary: const AlwaysStoppedAnimation<double>(0.5),
    );
    expect(find.byType(FadeTransition), findsNothing);
    expect(find.byType(ColoredBox), findsNothing);
  });

  test('exposes the Material 3 easing curves and recommended durations', () {
    expect(
      RakuTransitions.emphasizedDecelerate,
      const Cubic(0.05, 0.7, 0.1, 1.0),
    );
    expect(
      RakuTransitions.emphasizedAccelerate,
      const Cubic(0.3, 0.0, 0.8, 0.15),
    );
    expect(
      RakuTransitions.slideInDuration,
      const Duration(milliseconds: 320),
    );
    expect(
      RakuTransitions.slideInReverseDuration,
      const Duration(milliseconds: 280),
    );
  });
}
