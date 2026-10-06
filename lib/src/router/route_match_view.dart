import 'package:flutter/widgets.dart';

import '../branch.dart';
import '../page.dart';
import '../route.dart';
import '../stack.dart';
import '../stack_view.dart';
import 'route_node.dart';

/// The live navigation state for a resolved location (a `List<RouteMatch>` from
/// [RouteTree.match]): a tree of [RouteStack]s and [BranchedRouteStack]s that
/// mirrors the match, reusing [RouteStackView] for screens and
/// [BranchedStackView] for tabs — recursively, so **nested tabs** work. It is
/// mutable (navigation pushes/pops its stacks; tab switches change its
/// controllers) and the URL is derived from its active leaf.
class LiveLocation {
  /// Builds the live tree from [matches].
  LiveLocation(
    this.tree,
    List<RouteMatch> matches, {
    this.transitionsBuilder,
    this.transitionDuration = RakuTransitions.slideInDuration,
    this.observers,
  }) {
    root = _buildStack(matches);
  }

  /// The tree that maps routes to screens and transitions.
  final RouteTree tree;

  /// Default transition for screens.
  final RouteTransitionsBuilder? transitionsBuilder;

  /// Default transition duration.
  final Duration transitionDuration;

  /// Builds fresh [NavigatorObserver]s for each navigator in the live tree (the
  /// root and every branch). Called once per navigator, so no observer instance
  /// is shared across two [Navigator]s.
  final List<NavigatorObserver> Function()? observers;

  // The root navigator's observers, built once. `render` runs on every delegate
  // rebuild, so the factory must not be re-called there — that would swap in
  // fresh instances (leaking, and resetting stateful observers) each rebuild.
  // Each branch's observers are memoised the same way inside BranchedStackView.
  late final List<NavigatorObserver> _rootObservers =
      observers?.call() ?? const <NavigatorObserver>[];

  /// The root stack (its top may be a shell sentinel or a full-page screen).
  late final RouteStack root;

  final Map<int, _LiveTabs> _shells = <int, _LiveTabs>{};
  final List<RouteStack> _stacks = <RouteStack>[];
  final List<BranchedRouteStack> _controllers = <BranchedRouteStack>[];
  int _nextShellId = 0;

  RouteStack _buildStack(List<RouteMatch> matches) {
    final routes = <RakuRoute>[
      for (final match in matches)
        switch (match) {
          ScreenMatch(:final route) => route,
          TabsMatch() => _registerShell(match),
        },
    ];
    final stack = RouteStack.fromRoutes(routes);
    _stacks.add(stack);
    return stack;
  }

  _ShellSentinel _registerShell(TabsMatch match) {
    final id = _nextShellId++;
    final controller = BranchedRouteStack(
      branches: <RouteBranch>[
        for (var i = 0; i < match.branches.length; i++)
          RouteBranch.withStack(
            id: 'tab$i',
            stack: _buildStack(match.branches[i]),
          ),
      ],
      initialIndex: match.activeBranch,
    );
    _controllers.add(controller);
    _shells[id] = _LiveTabs(match.node, controller);
    return _ShellSentinel(id);
  }

  /// The deepest active screen route (descending through active tabs) — the
  /// route whose URL represents the whole location.
  RakuRoute get activeLeaf => activeLeafStack.current;

  /// The stack the deepest active screen lives on (a new push lands here).
  RouteStack get activeLeafStack => activeStacks.last;

  /// The visible chain of stacks, outermost first: the root, then the active
  /// branch of each shell on top, down to [activeLeafStack].
  List<RouteStack> get activeStacks {
    final chain = <RouteStack>[root];
    while (true) {
      final top = chain.last.current;
      if (top is! _ShellSentinel) return chain;
      chain.add(_shells[top.id]!.controller.activeStack);
    }
  }

  /// Subscribes [listener] to every stack and controller, so any navigation or
  /// tab switch anywhere fires it.
  void addListener(VoidCallback listener) {
    for (final stack in _stacks) {
      stack.addListener(listener);
    }
    for (final controller in _controllers) {
      controller.addListener(listener);
    }
  }

  /// Detaches [listener] (call before [dispose] if the delegate outlives this).
  void removeListener(VoidCallback listener) {
    for (final stack in _stacks) {
      stack.removeListener(listener);
    }
    for (final controller in _controllers) {
      controller.removeListener(listener);
    }
  }

  /// Reconciles the live tree to [matches] in place (from the same [tree], so
  /// the shell topology is fixed): switches each *targeted* shell to its matched
  /// branch and rebuilds the active path, while leaving inactive branches — and
  /// every page that didn't change — untouched.
  ///
  /// This is what makes a platform URL change (browser back/forward, a deep
  /// link) preserve state instead of rebuilding the whole tree: the other tabs
  /// keep their in-app history, and unchanged screens keep their element state.
  void reconcile(List<RouteMatch> matches) => _walk(
        root,
        matches,
        onStack: reconcileStack,
        onTab: (controller, index) => controller.index = index,
      );

  /// The guarded page that reconciling to [matches] would remove while its
  /// [RouteGuard.canPop] is `false` — with the stack it lives on — or null when
  /// the change is allowed. Lets a platform URL change (browser back/forward)
  /// honour a guard the same way the back button does.
  ({RouteGuard guard, RouteStack stack})? blockingGuard(
    List<RouteMatch> matches,
  ) {
    ({RouteGuard guard, RouteStack stack})? blocked;
    _walk(
      root,
      matches,
      onStack: (stack, routes) {
        final entries = stack.entries;
        // Entries past the longest unchanged prefix are the ones replaced.
        var kept = 0;
        while (kept < entries.length &&
            kept < routes.length &&
            entries[kept].route == routes[kept]) {
          kept++;
        }
        for (final entry in entries.skip(kept)) {
          final route = entry.route;
          if (route is RouteGuard && !route.canPop) {
            blocked ??= (guard: route, stack: stack);
          }
        }
      },
      onTab: (_, __) {},
    );
    return blocked;
  }

  // Walks [matches] against the live tree, reporting each stack's new routes
  // ([onStack]) and each shell's new active branch ([onTab]) — in the order a
  // reconcile applies them — without itself changing anything.
  void _walk(
    RouteStack stack,
    List<RouteMatch> matches, {
    required void Function(RouteStack stack, List<RakuRoute> routes) onStack,
    required void Function(BranchedRouteStack controller, int index) onTab,
  }) {
    // A shell that is the sole match is the URL's actual target: descend into it
    // and switch to the matched branch.
    if (matches.length == 1 && matches.first is TabsMatch) {
      final sentinel = stack.entries.first.route as _ShellSentinel;
      final match = matches.first as TabsMatch;
      final controller = _shells[sentinel.id]!.controller;
      // Only the matched branch follows the URL; the rest keep their stacks.
      _walk(
        controller.branches[match.activeBranch].stack,
        match.branches[match.activeBranch],
        onStack: onStack,
        onTab: onTab,
      );
      onTab(controller, match.activeBranch);
      onStack(stack, <RakuRoute>[sentinel]);
      return;
    }
    // Otherwise the matches are screens — optionally above a shell that merely
    // sits underneath a full-page route. That shell is preserved: its existing
    // sentinel stays in place and its controller is left untouched.
    final routes = <RakuRoute>[
      for (final match in matches)
        switch (match) {
          ScreenMatch(:final route) => route,
          TabsMatch() => stack.entries.first.route,
        },
    ];
    onStack(stack, routes);
  }

  /// Renders the live tree.
  Widget render({
    bool handleSystemBack = true,
    GlobalKey<NavigatorState>? navigatorKey,
  }) {
    return RouteStackView(
      stack: root,
      builder: _screenFor,
      navigatorKey: navigatorKey,
      observers: _rootObservers,
      transitionsBuilder: transitionsBuilder,
      transitionDuration: transitionDuration,
      resolveTransition: _transitionFor,
      handleSystemBack: handleSystemBack,
    );
  }

  Widget _screenFor(BuildContext context, RakuRoute route) {
    if (route is _ShellSentinel) {
      final live = _shells[route.id]!;
      return live.node.shell(
        context,
        live.controller,
        BranchedStackView(
          controller: live.controller,
          builder: _screenFor, // recursive: nested shells resolve here too
          observers: observers,
          transitionsBuilder: transitionsBuilder,
          transitionDuration: transitionDuration,
          resolveTransition: _transitionFor,
          handleSystemBack: false,
        ),
      );
    }
    return tree.screen(context, route);
  }

  // The shell sentinel has no tree node, so it gets the default transition.
  RouteTransitionsBuilder? _transitionFor(RakuRoute route) =>
      route is _ShellSentinel ? null : tree.transitionFor(route);

  /// Disposes every stack and controller it created.
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final stack in _stacks) {
      stack.dispose();
    }
  }
}

/// A live tabs shell: its [node] (for the shell builder) and the [controller]
/// that holds the preserved per-branch stacks.
class _LiveTabs {
  _LiveTabs(this.node, this.controller);
  final TabsNode node;
  final BranchedRouteStack controller;
}

/// A private marker route standing in for a tabs shell inside a [RouteStack].
/// Identity is its [id] (read directly in `_screenFor`); it never needs value
/// equality — a reconcile always hands a stack back its own sentinel instance.
class _ShellSentinel extends RakuRoute {
  const _ShellSentinel(this.id);
  final int id;
}
