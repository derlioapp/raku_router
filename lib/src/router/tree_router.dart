import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../page.dart';
import '../route.dart';
import '../stack_view.dart';
import 'route_match_view.dart';
import 'route_node.dart';

/// Builds a [RouterConfig] from a declarative **route tree** ([route] / [tabs]).
///
/// A URL's path *structure* reconstructs the navigation stack, so a deep link
/// into a nested route restores its back history; tabs resolve to the right
/// branch (and rebuild its stack); top-level routes sit full-page above any tabs
/// shell. Navigate with typed objects — `context.push(const Note('42'))` — and
/// the address bar follows; the premium [RakuTransitions.slideIn] is the
/// default.
///
/// Pass [onNavigation] to observe navigation in terms of your typed routes (for
/// analytics/logging): it fires with the active leaf route after every change
/// that moves it — a push, pop, tab switch, or browser back/forward — once per
/// change, and not for the initial route (you already have `initial`).
///
/// ```dart
/// MaterialApp.router(routerConfig: raku(
///   initial: const Feed(),
///   routes: [
///     tabs(shell: ..., branches: [
///       [ route('/feed', (_) => const Feed(), (_) => const FeedScreen(), children: [
///           route('notes/:id', (p) => Note(p('id')), (n) => NoteScreen(id: n.id)),
///       ]) ],
///       [ route('/settings', (_) => const Settings(), (_) => const SettingsScreen()) ],
///     ]),
///     route('/photo/:id', (p) => Photo(p('id')), (n) => PhotoScreen(id: n.id)),
///   ],
/// ));
/// ```
RouterConfig<RakuRoute> raku({
  required List<RouteNode> routes,
  required RakuRoute initial,
  RakuRoute Function(Uri uri)? onUnknown,
  RouteTransitionsBuilder? transition,
  Duration transitionDuration = RakuTransitions.slideInDuration,
  void Function(RakuRoute route)? onNavigation,
}) {
  final tree = RouteTree(routes);
  final delegate = _TreeRouterDelegate(
    tree: tree,
    initial: initial,
    transitionsBuilder: transition ?? RakuTransitions.slideIn(),
    transitionDuration: transitionDuration,
    onNavigation: onNavigation,
  );
  return RouterConfig<RakuRoute>(
    routerDelegate: delegate,
    routeInformationParser: _TreeParser(tree, onUnknown ?? (_) => initial),
    routeInformationProvider: PlatformRouteInformationProvider(
      initialRouteInformation: RouteInformation(uri: tree.locationOf(initial)),
    ),
    backButtonDispatcher: RootBackButtonDispatcher(),
  );
}

// The deepest active screen route of a resolved location.
RakuRoute _leafOf(List<RouteMatch> matches) {
  final last = matches.last;
  return switch (last) {
    ScreenMatch(:final route) => route,
    TabsMatch(:final activeBranch, :final branches) =>
      _leafOf(branches[activeBranch]),
  };
}

class _TreeRouterDelegate extends RouterDelegate<RakuRoute>
    with ChangeNotifier {
  _TreeRouterDelegate({
    required this.tree,
    required RakuRoute initial,
    required this.transitionsBuilder,
    required this.transitionDuration,
    this.onNavigation,
  }) {
    _setLocation(tree.locationOf(initial));
    _lastLeaf = _location.activeLeaf;
  }

  final RouteTree tree;
  final RouteTransitionsBuilder transitionsBuilder;
  final Duration transitionDuration;

  /// Reports the active leaf route after every navigation that changes it.
  final void Function(RakuRoute route)? onNavigation;

  // The last route reported to onNavigation, to fire only on a real change.
  RakuRoute? _lastLeaf;

  // Keys the root navigator so popRoute can reach a BuildContext for a guard's
  // onPopBlocked (e.g. a confirm dialog) on the discrete system back button.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  late LiveLocation _location;

  void _setLocation(Uri uri) {
    _location = LiveLocation(
      tree,
      tree.match(uri)!,
      transitionsBuilder: transitionsBuilder,
      transitionDuration: transitionDuration,
    )..addListener(_handleChange);
  }

  // Any stack/controller change funnels here: notify the Router, and — when the
  // active leaf actually changed — report it to onNavigation exactly once.
  void _handleChange() {
    final leaf = _location.activeLeaf;
    if (leaf != _lastLeaf) {
      _lastLeaf = leaf;
      onNavigation?.call(leaf);
    }
    notifyListeners();
  }

  @override
  RakuRoute get currentConfiguration => _location.activeLeaf;

  @override
  Widget build(BuildContext context) {
    return RakuNavigator(
      onPush: _push,
      child: _location.render(
        handleSystemBack: false,
        navigatorKey: _navigatorKey,
      ),
    );
  }

  // Route a push to its level: a top-level route to the root (full-page above
  // the shell), a tab route into the active tab's stack.
  Future<void> _push(RakuRoute route) =>
      (tree.isRootLevel(route) ? _location.root : _location.activeLeafStack)
          .push(route);

  @override
  Future<void> setNewRoutePath(RakuRoute configuration) async {
    // Resolve redirects on URL entry too, so a RouteRedirect reached via a deep
    // link behaves like one reached via push — and route by the *resolved*
    // route's level: a tab route that redirects to a full-page route lands above
    // the shell, because its resolved URL reconstructs that structure.
    final resolved = await _location.root.resolve(configuration);
    // Reconcile the live tree to the resolved location *in place* rather than
    // rebuilding it: the active path follows the URL while the other branches —
    // and every unchanged page — keep their state, so a browser back/forward
    // doesn't reset the inactive tabs. (In-app navigation already mutates the
    // live stacks directly; this brings platform URL changes in line.)
    _location.reconcile(tree.match(tree.locationOf(resolved))!);
    notifyListeners();
  }

  @override
  Future<bool> popRoute() {
    final stack = _location.activeLeafStack;
    final top = stack.current;
    // The discrete system back button is routed here (the nested navigators run
    // with handleSystemBack: false). Honour a guarded leaf the same way every
    // other pop path does: veto, and run onPopBlocked (e.g. a confirm dialog)
    // with the root navigator's context — matching `context.pop()`.
    if (top is RouteGuard && !top.canPop) {
      final context = _navigatorKey.currentContext;
      if (context != null) top.onPopBlocked(context);
      return SynchronousFuture<bool>(false);
    }
    return stack.pop();
  }

  @override
  void dispose() {
    _location.removeListener(_handleChange);
    _location.dispose();
    super.dispose();
  }
}

class _TreeParser extends RouteInformationParser<RakuRoute> {
  _TreeParser(this._tree, this._onUnknown);

  final RouteTree _tree;
  final RakuRoute Function(Uri uri) _onUnknown;

  @override
  Future<RakuRoute> parseRouteInformation(
    RouteInformation routeInformation,
  ) {
    final uri = routeInformation.uri;
    final matched = _tree.match(uri);
    return SynchronousFuture<RakuRoute>(
      matched == null ? _onUnknown(uri) : _leafOf(matched),
    );
  }

  @override
  RouteInformation? restoreRouteInformation(RakuRoute configuration) =>
      RouteInformation(uri: _tree.locationOf(configuration));
}
