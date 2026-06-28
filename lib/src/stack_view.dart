import 'package:flutter/widgets.dart';

import 'page.dart';
import 'route.dart';
import 'stack.dart';

/// Builds the screen widget for a given [RakuRoute].
///
/// Make this a `switch` over your sealed route type so the compiler enforces
/// that every route is handled — no code generation required.
typedef RakuWidgetBuilder = Widget Function(
  BuildContext context,
  RakuRoute route,
);

/// Renders a [RouteStack] as a [Navigator].
///
/// Works in two modes:
///  * **Simple / no deep linking** — drop it straight into `MaterialApp.home`
///    (or any design system's app shell). Keep [handleSystemBack] `true` so the
///    nested navigator handles the system back gesture.
///  * **Deep linking** — used internally by the `raku(...)` router delegate;
///    there the Router owns back handling, so [handleSystemBack] is `false`.
class RouteStackView extends StatelessWidget {
  /// Creates a view that renders [stack] as a [Navigator].
  const RouteStackView({
    super.key,
    required this.stack,
    required this.builder,
    this.pageBuilder,
    this.observers = const <NavigatorObserver>[],
    this.navigatorKey,
    this.handleSystemBack = true,
    this.transitionDuration = const Duration(milliseconds: 250),
    this.transitionsBuilder = RakuTransitions.fade,
    this.resolveTransition,
  });

  /// The stack to render.
  final RouteStack stack;

  /// Maps each route to its screen widget.
  final RakuWidgetBuilder builder;

  /// Optional custom default page factory. If null, [RakuPage] is used
  /// (with [transitionsBuilder] / [transitionDuration]). Routes that mix in
  /// `RouteTransition` always win over this.
  final RakuPageBuilder? pageBuilder;

  /// Navigator observers forwarded to the underlying [Navigator].
  final List<NavigatorObserver> observers;

  /// Optional key for the underlying [Navigator] (used by the deep-link
  /// delegate so the back-button dispatcher can find it).
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Whether to wrap the navigator in a [NavigatorPopHandler] so the system
  /// back gesture pops this stack. Set to `false` when an outer Router handles
  /// back (deep-link mode).
  final bool handleSystemBack;

  /// Default forward/reverse transition duration when [pageBuilder] is null.
  final Duration transitionDuration;

  /// Default transition when [pageBuilder] is null.
  final RouteTransitionsBuilder transitionsBuilder;

  /// Optional per-route transition lookup. When it returns non-null for a route,
  /// that transition is used instead of [transitionsBuilder]. Lets the declarative
  /// router apply a route's own `transition:` while keeping a global default.
  final RouteTransitionsBuilder? Function(RakuRoute route)? resolveTransition;

  Page<Object?> _pageFor(BuildContext context, RakuEntry entry) {
    final route = entry.route;
    var child = builder(context, route);

    // A guarded route reports its pop-ability to the framework via PopScope, so
    // the guard is honoured by predictive back and imperative pops too.
    if (route is RouteGuard) {
      child = _GuardedScreen(guard: route, child: child);
    }
    if (route is RouteTransition) {
      return route.buildPage(child, entry.pageKey);
    }
    if (pageBuilder != null) {
      return pageBuilder!(child, entry.pageKey, route.name);
    }
    return RakuPage<Object?>(
      key: entry.pageKey,
      name: route.name,
      transitionDuration: transitionDuration,
      reverseTransitionDuration: transitionDuration,
      transitionsBuilder: resolveTransition?.call(route) ?? transitionsBuilder,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget result = ListenableBuilder(
      listenable: stack,
      builder: (context, _) {
        return Navigator(
          key: navigatorKey,
          observers: observers,
          pages: <Page<Object?>>[
            for (final entry in stack.entries) _pageFor(context, entry),
          ],
          onDidRemovePage: (page) => stack.handlePageRemoved(page.key),
        );
      },
    );

    if (handleSystemBack) {
      result = NavigatorPopHandler(
        onPopWithResult: (_) => stack.pop(),
        child: result,
      );
    }

    // Expose this stack to descendant screens via RouteStackScope.of(context).
    return RouteStackScope(stack: stack, child: result);
  }
}

/// Makes the nearest enclosing [RouteStack] available to descendant screens.
///
/// Inserted automatically by [RouteStackView] (and therefore by
/// `BranchedStackView`), so a screen can navigate without the stack being
/// threaded through constructors:
///
/// ```dart
/// final stack = RouteStackScope.of(context);
/// stack.push(const NoteDetail('42'));
/// ```
class RouteStackScope extends InheritedWidget {
  /// Exposes [stack] to the subtree under [child].
  const RouteStackScope({
    super.key,
    required this.stack,
    required super.child,
  });

  /// The stack owning the subtree below this scope.
  final RouteStack stack;

  /// The nearest stack above [context]. Asserts if there is none.
  static RouteStack of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RouteStackScope>();
    assert(
      scope != null,
      'Raku: no RouteStackScope above this context. Render your screens '
      'inside a RouteStackView (or BranchedStackView) before calling '
      'RouteStackScope.of / context.routeStack.',
    );
    return scope!.stack;
  }

  /// The nearest stack above [context], or null if there is none.
  static RouteStack? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RouteStackScope>()?.stack;

  @override
  bool updateShouldNotify(RouteStackScope oldWidget) =>
      oldWidget.stack != stack;
}

/// Routes a push through a router that knows where each route belongs — a
/// full-page (root) route goes above the tab shell, a tab route into the active
/// tab. Inserted by the `raku(...)` router when the tree has a `tabs(...)`
/// node; absent in plain single-stack apps, where `context.push` falls back to
/// the nearest [RouteStack].
class RakuNavigator extends InheritedWidget {
  /// Wraps [child], exposing [onPush] to descendants.
  const RakuNavigator({
    super.key,
    required this.onPush,
    required super.child,
  });

  /// Pushes a route onto the correct stack for its kind.
  final Future<void> Function(RakuRoute route) onPush;

  /// The nearest navigator above [context], or null if there is none.
  ///
  /// Deliberately a non-dependency lookup (`getInheritedWidgetOfExactType`):
  /// [onPush] is a stable closure, so push call-sites must not rebuild when it
  /// changes — which is why [updateShouldNotify] is always `false`. Don't switch
  /// this to `dependOnInheritedWidgetOfExactType`.
  static RakuNavigator? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<RakuNavigator>();

  @override
  bool updateShouldNotify(RakuNavigator oldWidget) => false;
}

/// Ergonomic [RouteStack] access from a [BuildContext].
///
/// Sugar over [RouteStackScope]: `context.routeStack` reads the nearest stack
/// exactly like `RouteStackScope.of(context)`, for shorter call sites:
///
/// ```dart
/// context.routeStack.push(const NoteDetail('42'));
/// ```
extension RouteStackContext on BuildContext {
  /// The nearest [RouteStack] above this context. Asserts if there is none.
  RouteStack get routeStack => RouteStackScope.of(this);

  /// The nearest [RouteStack] above this context, or null if there is none.
  RouteStack? get routeStackOrNull => RouteStackScope.maybeOf(this);

  /// Pushes [route]. In a tabbed app (where a [RakuNavigator] is present)
  /// raku_router sends a full-page route above the shell and a tab route into the
  /// active tab; otherwise it pushes onto the nearest [RouteStack].
  Future<void> push(RakuRoute route) {
    final navigator = RakuNavigator.maybeOf(this);
    if (navigator != null) return navigator.onPush(route);
    return routeStack.push(route);
  }

  /// Pops the top route of the nearest stack. If that route's [RouteGuard]
  /// blocks the pop, its `onPopBlocked` runs (e.g. to confirm) and nothing is
  /// popped — matching the predictive-back behaviour. Stack-local (it does not
  /// consult [RakuNavigator]): you pop the level you're on.
  Future<bool> pop() {
    final stack = routeStack;
    final top = stack.current;
    if (top is RouteGuard && !top.canPop) {
      top.onPopBlocked(this);
      return Future<bool>.value(false);
    }
    return stack.pop();
  }

  /// Replaces the top route of the nearest stack. Stack-local, like [pop].
  Future<void> replace(RakuRoute route) => routeStack.replace(route);
}

/// Wraps a [RouteGuard] route's screen in a [PopScope] so its [RouteGuard.canPop]
/// is honoured by every pop path (predictive back, imperative `Navigator.pop`,
/// system back), re-evaluating when [RouteGuard.rebuildOn] changes.
class _GuardedScreen extends StatelessWidget {
  const _GuardedScreen({required this.guard, required this.child});

  final RouteGuard guard;
  final Widget child;

  Widget _scope(BuildContext context) => PopScope(
        canPop: guard.canPop,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) guard.onPopBlocked(context);
        },
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final rebuildOn = guard.rebuildOn;
    if (rebuildOn == null) return _scope(context);
    return ListenableBuilder(
      listenable: rebuildOn,
      builder: (context, _) => _scope(context),
    );
  }
}
