import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Base class for every destination in a Raku application.
///
/// Define your own routes by extending this — ideally as a `sealed` hierarchy,
/// so the `switch` in your [RakuWidgetBuilder] is checked for
/// exhaustiveness by the compiler. Raku needs **no code generation**:
/// type-safety comes from
/// Dart's sealed classes and exhaustive `switch`, not from a build step.
///
/// ```dart
/// sealed class AppRoute extends RakuRoute {
///   const AppRoute();
/// }
///
/// class Home extends AppRoute {
///   const Home();
/// }
///
/// class NoteDetail extends AppRoute {
///   const NoteDetail(this.id);
///   final String id;
///   @override
///   List<Object?> get props => [id];
/// }
/// ```
@immutable
abstract class RakuRoute {
  /// Const constructor so concrete routes can be const.
  const RakuRoute();

  /// Values that make this destination unique (e.g. an `id`).
  ///
  /// Two routes of the same type with equal [props] describe the *same*
  /// destination — used for redirect-loop detection and [RouteStack.popUntil]
  /// matching. Defaults to an empty list (parameterless singleton destination).
  List<Object?> get props => const <Object?>[];

  /// Human-readable name, surfaced as the page name for debugging/observers.
  String get name => runtimeType.toString();

  /// Whether [other] points at the same destination as this route.
  ///
  /// Identical to `this == other`; kept as a named alias because it reads
  /// clearly at redirect/loop-detection call sites.
  bool sameDestination(RakuRoute other) => this == other;

  /// Value equality from `(runtimeType, props)`: two routes of the same type
  /// with equal [props] are equal, even when they are distinct (non-const)
  /// instances. Page identity on a [RouteStack] is tracked separately (by a
  /// process-unique entry id), so equal routes can still coexist on the stack.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RakuRoute &&
          runtimeType == other.runtimeType &&
          listEquals(props, other.props));

  @override
  int get hashCode => Object.hash(runtimeType, Object.hashAll(props));

  @override
  String toString() =>
      props.isEmpty ? name : '$name(${props.map((p) => '$p').join(', ')})';
}

/// Lets a route veto being popped — e.g. a screen with unsaved changes.
///
/// raku_router wraps a guarded screen in a [PopScope], so [canPop] is honoured by
/// **every** pop path: the predictive-back gesture, an imperative
/// `Navigator.pop`, the system back button, and `controller.pop()`. It is read
/// **synchronously** (predictive back needs a sync answer); return `false` to
/// block. Use [onPopBlocked] to confirm-then-pop (e.g. a "discard changes?"
/// dialog), and [rebuildOn] to re-evaluate [canPop] as state changes.
mixin RouteGuard on RakuRoute {
  /// Whether this route may be popped right now. Return `false` to block.
  bool get canPop;

  /// A listenable that re-evaluates [canPop] when it changes (so a block can
  /// turn on and off). Optional.
  Listenable? get rebuildOn => null;

  /// Called when a blocked pop is attempted (e.g. a back swipe while [canPop] is
  /// `false`). Confirm here — await a dialog, then `context.pop()` if agreed.
  void onPopBlocked(BuildContext context) {}
}

/// Resolves a redirect before the route is shown.
///
/// Return a different [RakuRoute] to redirect, or `null`/the same
/// destination to stay. Redirect chains are followed and protected against
/// infinite loops.
mixin RouteRedirect on RakuRoute {
  /// Return the route to redirect to, or `null` to stay on this one.
  FutureOr<RakuRoute?> redirect();
}

/// Overrides the [Page] (and therefore the transition) used for this route.
///
/// When a route does not mix this in, the host's default page/transition is
/// used. The provided [key] **must** be forwarded to the returned page so the
/// stack can track it.
mixin RouteTransition on RakuRoute {
  /// Build the page that presents [child]. Forward [key] to the page.
  Page<Object?> buildPage(Widget child, LocalKey key);
}
