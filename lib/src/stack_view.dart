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
    this.transitionDuration = RakuTransitions.slideInDuration,
    this.transitionsBuilder,
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

  /// Optional key for the underlying [Navigator]. When null, raku_router keys
  /// it itself (one navigator per [stack]), so system back can reach an
  /// imperatively shown dialog or sheet on it.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Whether to wrap the navigator in a [NavigatorPopHandler] so the system
  /// back gesture pops this stack. Set to `false` when an outer Router handles
  /// back (deep-link mode).
  final bool handleSystemBack;

  /// Default forward/reverse transition duration when [pageBuilder] is null.
  final Duration transitionDuration;

  /// Default transition when [pageBuilder] is null; null uses the premium
  /// [RakuTransitions.slideIn].
  final RouteTransitionsBuilder? transitionsBuilder;

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
    final key = navigatorKey ??
        (_navigatorKeys[stack] ??=
            GlobalKey<NavigatorState>(debugLabel: 'raku_router'));
    _navigatorKeys[stack] = key;
    Widget result = ListenableBuilder(
      listenable: stack,
      builder: (context, _) {
        return Navigator(
          key: key,
          observers: observers,
          pages: <Page<Object?>>[
            for (final entry in stack.entries) _pageFor(context, entry),
          ],
          onDidRemovePage: (page) => removeStackPage(stack, page.key),
        );
      },
    );

    if (handleSystemBack) {
      result = NavigatorPopHandler(
        // A dialog/sheet shown on this navigator is dismissed first; only then
        // does back pop a page.
        onPopWithResult: (_) => popOverlay(stack) ?? stack.pop(),
        child: result,
      );
    }

    // Expose this stack to descendant screens via RouteStackScope.of(context).
    return RouteStackScope(stack: stack, child: result);
  }
}

// The navigator rendering each stack, so system back can find an imperatively
// shown overlay (dialog, bottom sheet, menu) sitting on top of its pages.
final Expando<GlobalKey<NavigatorState>> _navigatorKeys =
    Expando<GlobalKey<NavigatorState>>('raku_router navigators');

/// The navigator currently rendering [stack], if mounted. Package-internal.
NavigatorState? navigatorOfStack(RouteStack stack) =>
    _navigatorKeys[stack]?.currentState;

/// Dismisses the overlay (a dialog, bottom sheet, menu — any route that isn't
/// one of [stack]'s pages) on top of [stack]'s navigator, honouring its own
/// `PopScope`. Returns null when there is none, so the caller pops a page
/// instead. Package-internal.
Future<bool>? popOverlay(RouteStack stack) {
  final navigator = navigatorOfStack(stack);
  if (navigator == null) return null;
  Route<Object?>? top;
  // A predicate that accepts the first route it sees reads the top route
  // without popping anything.
  navigator.popUntil((route) {
    top = route;
    return true;
  });
  if (top == null || top!.settings is Page<Object?>) return null;
  return navigator.maybePop();
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

/// Routes `context.push` / `context.go` through the `raku(...)` router, which
/// knows where each route belongs — a full-page (root) route goes above the tab
/// shell, a tab route into the active tab. Inserted by the router; absent in
/// plain [RouteStackView] apps, where those calls fall back to the nearest
/// [RouteStack]. Package-internal (hidden from the public library).
class RakuNavigator extends InheritedWidget {
  /// Wraps [child], exposing [onPush] and [onGo] to descendants.
  const RakuNavigator({
    super.key,
    required this.onPush,
    required this.onGo,
    required super.child,
  });

  /// Pushes a route onto the correct stack for its kind.
  final Future<void> Function(RakuRoute route) onPush;

  /// Navigates to a route the way a deep link would (rebuilding the stack).
  final Future<void> Function(RakuRoute route) onGo;

  /// The nearest navigator above [context], or null if there is none.
  ///
  /// Deliberately a non-dependency lookup (`getInheritedWidgetOfExactType`):
  /// [onPush] / [onGo] are stable closures, so call-sites must not rebuild when
  /// they change — which is why [updateShouldNotify] is always `false`. Don't switch
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

  /// Pushes [route]. Under a `raku(...)` router, a full-page route goes above the tab
  /// shell and a tab route into the active tab; otherwise it pushes onto the
  /// nearest [RouteStack].
  Future<void> push(RakuRoute route) {
    final navigator = RakuNavigator.maybeOf(this);
    if (navigator != null) return navigator.onPush(route);
    return routeStack.push(route);
  }

  /// Navigates to [route] **the way a deep link would**: under a `raku(...)` router
  /// the whole location is rebuilt from [route]'s URL (its ancestors become the
  /// back stack, the right tab is selected) — e.g. "after sign-in, go to the
  /// dashboard". See `RakuRouter.go`.
  ///
  /// Outside a `raku(...)` router there is no route tree, so the nearest
  /// [RouteStack] is reset to [route] (after following any [RouteRedirect]).
  Future<void> go(RakuRoute route) {
    final navigator = RakuNavigator.maybeOf(this);
    if (navigator != null) return navigator.onGo(route);
    final stack = routeStack;
    return resolveRedirects(route).then(stack.reset);
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

  /// Like [replace], but updates the address bar **in place** — no new browser
  /// history entry, so back/forward skips it. Use for transient URL state you
  /// don't want to litter history: a search query, an active filter, a within-
  /// page selection you still want to be shareable/restorable.
  ///
  /// Wraps Flutter's [Router.neglect]. Outside a deep-linked ([raku]) app there
  /// is no Router (and no URL), so it degrades to a plain [replace]. Meant for
  /// plain routes; a `RouteRedirect` resolves asynchronously, after the neglect
  /// window closes, so its history entry is not suppressed.
  void replaceSilently(RakuRoute route) {
    if (Router.maybeOf(this) == null) {
      replace(route);
      return;
    }
    Router.neglect(this, () => replace(route));
  }
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
