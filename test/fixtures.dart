// Shared route fixtures for the raku_router test-suite. A single sealed hierarchy
// lets every widget-test `switch` stay exhaustive without code generation.
import 'package:flutter/widgets.dart';
import 'package:raku_router/raku_router.dart';

sealed class TestRoute extends RakuRoute {
  const TestRoute();
}

/// A simple route.
class Home extends TestRoute {
  const Home();
}

/// A parameterised route (props back its value-equality and URL building).
class Note extends TestRoute {
  const Note(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

/// A plain (non-addressable) route.
class Plain extends TestRoute {
  const Plain();
}

/// A full-page (root-level) route for tabbed-router tests.
class FullScreen extends TestRoute {
  const FullScreen(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

/// Vetoes its own pop when [allow] is false.
class Guarded extends TestRoute with RouteGuard {
  const Guarded({required this.allow});
  final bool allow;
  @override
  bool get canPop => allow;
}

/// Synchronously redirects to [Home].
class Legacy extends TestRoute with RouteRedirect {
  const Legacy();
  @override
  RakuRoute redirect() => const Home();
}

/// A tab-level route that redirects to a full-page (root) route — for testing
/// that level routing respects the *resolved* route.
class ToFullScreen extends TestRoute with RouteRedirect {
  const ToFullScreen();
  @override
  RakuRoute redirect() => const FullScreen('x');
}

/// Two-hop chain: [LegacyChain] → [Legacy] → [Home].
class LegacyChain extends TestRoute with RouteRedirect {
  const LegacyChain();
  @override
  RakuRoute redirect() => const Legacy();
}

/// Asynchronously redirects to [Home].
class AsyncRedirect extends TestRoute with RouteRedirect {
  const AsyncRedirect();
  @override
  Future<RakuRoute?> redirect() async {
    await Future<void>.delayed(Duration.zero);
    return const Home();
  }
}

/// Redirects to its own destination → resolves to itself (no-op redirect).
class SelfRedirect extends TestRoute with RouteRedirect {
  const SelfRedirect();
  @override
  RakuRoute redirect() => const SelfRedirect();
}

/// Half of an infinite redirect loop with [LoopB].
class LoopA extends TestRoute with RouteRedirect {
  const LoopA();
  @override
  RakuRoute redirect() => const LoopB();
}

/// Half of an infinite redirect loop with [LoopA].
class LoopB extends TestRoute with RouteRedirect {
  const LoopB();
  @override
  RakuRoute redirect() => const LoopA();
}

/// Overrides the default page with a slide transition.
class Sheet extends TestRoute with RouteTransition {
  const Sheet();
  @override
  Page<Object?> buildPage(Widget child, LocalKey key) => RakuPage<Object?>(
        key: key,
        transitionsBuilder: RakuTransitions.slide,
        child: child,
      );
}

/// Maps every [TestRoute] to a labelled [Text] screen for widget tests.
Widget buildScreen(BuildContext context, RakuRoute route) {
  return switch (route as TestRoute) {
    Home() => const Text('home'),
    Note(:final id) => Text('note-$id'),
    Plain() => const Text('plain'),
    FullScreen(:final id) => Text('full-$id'),
    ToFullScreen() => const Text('to-full'),
    Guarded() => const Text('guarded'),
    Legacy() => const Text('legacy'),
    LegacyChain() => const Text('legacy-chain'),
    AsyncRedirect() => const Text('async'),
    SelfRedirect() => const Text('self'),
    LoopA() => const Text('loopA'),
    LoopB() => const Text('loopB'),
    Sheet() => const Text('sheet'),
  };
}
