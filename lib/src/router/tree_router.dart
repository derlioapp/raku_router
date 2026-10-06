import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../page.dart';
import '../route.dart';
import '../stack.dart';
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
/// Pass [observers] to attach `NavigatorObserver`s (e.g. `FirebaseAnalyticsObserver`,
/// `SentryNavigatorObserver`) to the navigators. It is a **factory**, not a list:
/// a single observer instance can only attach to one `Navigator`, and Raku builds
/// several (the root plus one per tab branch), so the factory is called once per
/// navigator to give each its own fresh instances — this way an observer sees
/// in-tab pushes too, not just top-level ones. (For plain route-name analytics,
/// [onNavigation] is simpler and already covers every navigator.)
///
/// Pass [title] as the fallback browser tab / task-switcher label for routes
/// whose `route(...)` declares no `title:` — without it, leaving a titled route
/// for an untitled one would keep the old label.
///
/// A URL that matches no route — or whose `parse` throws on malformed input,
/// like `p.asInt('id')` on `/notes/abc` — goes to [onUnknown] (default:
/// [initial]); a bad deep link never crashes the app.
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
RakuRouter raku({
  required List<RouteNode> routes,
  required RakuRoute initial,
  RakuRoute Function(Uri uri)? onUnknown,
  RouteTransitionsBuilder? transition,
  Duration transitionDuration = RakuTransitions.slideInDuration,
  void Function(RakuRoute route)? onNavigation,
  List<NavigatorObserver> Function()? observers,
  String Function(RakuRoute route)? title,
}) {
  final tree = RouteTree(routes);
  final delegate = _TreeRouterDelegate(
    tree: tree,
    initial: initial,
    transitionsBuilder: transition,
    transitionDuration: transitionDuration,
    onNavigation: onNavigation,
    observers: observers,
    title: title,
  );
  return RakuRouter._(
    tree: tree,
    delegate: delegate,
    routeInformationParser: _TreeParser(tree, onUnknown ?? (_) => initial),
    routeInformationProvider: PlatformRouteInformationProvider(
      initialRouteInformation: RouteInformation(uri: tree.locationOf(initial)),
    ),
    backButtonDispatcher: RootBackButtonDispatcher(),
  );
}

/// The [RouterConfig] that [raku] returns: hand it to `MaterialApp.router`, and
/// keep it as your app's **navigation handle** for code that has no
/// `BuildContext` — a push-notification handler, an auth listener, a service:
///
/// ```dart
/// final router = raku(initial: const Home(), routes: [...]);
///
/// auth.addListener(() {
///   if (!auth.isSignedIn) router.go(const Login()); // logout → login, anywhere
/// });
/// onNotificationTap((uri) {
///   final route = router.routeOf(uri);
///   if (route != null) router.push(route);
/// });
/// ```
///
/// It also exposes the tree's **route → URL** direction ([uriOf] / [hrefOf]) for
/// share links and `<a href>`s.
final class RakuRouter extends RouterConfig<RakuRoute> {
  RakuRouter._({
    required RouteTree tree,
    required _TreeRouterDelegate delegate,
    required super.routeInformationParser,
    required super.routeInformationProvider,
    required super.backButtonDispatcher,
  })  : _tree = tree,
        _delegate = delegate,
        super(routerDelegate: delegate);

  final RouteTree _tree;
  final _TreeRouterDelegate _delegate;

  /// The active leaf route — what the user is looking at — as a listenable.
  ///
  /// Updates after every navigation that changes it (push, pop, tab switch,
  /// browser back/forward, [go]); bind UI to it with a `ValueListenableBuilder`,
  /// e.g. to highlight the current item in a custom side menu.
  ValueListenable<RakuRoute> get current => _delegate.current;

  /// Navigates to [route] **the way a deep link would**: the whole location is
  /// rebuilt from [route]'s URL — its ancestors become the back stack and the
  /// right tab is selected — after following any [RouteRedirect]. The address
  /// bar gets a new history entry.
  ///
  /// Use it to *reset* navigation: after sign-in or sign-out, or to open a
  /// notification's screen with a sensible back stack. Unlike a back gesture, it
  /// is an explicit app decision, so [RouteGuard]s don't veto it. From a widget,
  /// `context.go(route)` does the same.
  Future<void> go(RakuRoute route) => _delegate.go(route);

  /// Pushes [route] on top of the current location — a full-page route above
  /// the tab shell, a tab route into the active tab — like `context.push`.
  Future<void> push(RakuRoute route) => _delegate.push(route);

  /// The route [uri] resolves to, or null if no route claims it (a catch-all
  /// route counts as a claim) or its `parse` rejects it. The URL → route
  /// direction, for a link from outside the app (a push payload, a QR code) —
  /// which is untrusted input, so this never throws:
  ///
  /// ```dart
  /// final route = router.routeOf(Uri.tryParse(payload) ?? Uri());
  /// if (route != null) router.go(route);
  /// ```
  RakuRoute? routeOf(Uri uri) {
    final matched = _tree.match(uri);
    return matched == null ? null : _leafOf(matched);
  }

  /// The location [route] maps to (path `:params` + any `?query`) — the exact
  /// URL the address bar shows when [route] is the active leaf, built by the
  /// same tree that parses URLs, so it always stays in sync. Asserts if [route]
  /// has no `route(...)` node.
  Uri uriOf(RakuRoute route) => _tree.locationOf(route);

  /// [uriOf] rendered as a string — the `href` for an anchor or share link,
  /// e.g. `hrefOf(const Note('42'))` → `'/feed/notes/42'`.
  ///
  /// This is the app-internal location. It matches the browser address bar
  /// under the path URL strategy (`usePathUrlStrategy`); under the default hash
  /// strategy the bar shows it after a `#`, so prefix a real anchor with `#`.
  String hrefOf(RakuRoute route) => uriOf(route).toString();
}

// Every screen route on a resolved location's active path, outermost first
// (descending through each shell's active branch) — the leaf is last.
Iterable<RakuRoute> _activePath(List<RouteMatch> matches) sync* {
  for (final match in matches) {
    switch (match) {
      case ScreenMatch(:final route):
        yield route;
      case TabsMatch(:final activeBranch, :final branches):
        yield* _activePath(branches[activeBranch]);
    }
  }
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
    this.transitionsBuilder,
    required this.transitionDuration,
    this.onNavigation,
    this.observers,
    this.title,
  }) {
    _setLocation(tree.locationOf(initial));
    current = ValueNotifier<RakuRoute>(_location.activeLeaf);
  }

  final RouteTree tree;
  final RouteTransitionsBuilder? transitionsBuilder;
  final Duration transitionDuration;

  /// Builds fresh navigator observers for the root and each branch navigator.
  final List<NavigatorObserver> Function()? observers;

  /// Reports the active leaf route after every navigation that changes it.
  final void Function(RakuRoute route)? onNavigation;

  /// The fallback title for routes whose node declares none.
  final String Function(RakuRoute route)? title;

  /// The active leaf route; changes (by value) drive [onNavigation].
  late final ValueNotifier<RakuRoute> current;

  // Keys the root navigator; the context for a guard's onPopBlocked when its
  // own stack's navigator isn't mounted.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  late LiveLocation _location;

  // Bumped by every location change ([_navigate]), so a slow async redirect of
  // an older one can't land after — and overwrite — a newer one.
  int _ticket = 0;

  void _setLocation(Uri uri) {
    _location = LiveLocation(
      tree,
      tree.match(uri)!,
      transitionsBuilder: transitionsBuilder,
      transitionDuration: transitionDuration,
      observers: observers,
    )..addListener(_handleChange);
  }

  // Any stack/controller change funnels here: notify the Router, and — when the
  // active leaf actually changed — publish it and report it to onNavigation
  // exactly once.
  void _handleChange() {
    final leaf = _location.activeLeaf;
    if (leaf != current.value) {
      current.value = leaf;
      onNavigation?.call(leaf);
    }
    notifyListeners();
  }

  @override
  RakuRoute get currentConfiguration => _location.activeLeaf;

  // The last title pushed to the platform, so we call the channel only when it
  // changes (build runs on every navigation).
  String? _lastTitle;

  // Mirror Flutter's own Title widget: set the browser tab / task-switcher
  // label from the active leaf's `title:` (else the router-wide fallback). A
  // no-op — never touching the platform — when no title is declared anywhere,
  // so the feature stays opt-in.
  void _applyTitle() {
    final leaf = currentConfiguration;
    final label = tree.titleFor(leaf) ?? title?.call(leaf);
    if (label == null || label == _lastTitle) return;
    _lastTitle = label;
    SystemChrome.setApplicationSwitcherDescription(
      ApplicationSwitcherDescription(label: label),
    );
  }

  @override
  Widget build(BuildContext context) {
    _applyTitle();
    return RakuNavigator(
      onPush: push,
      onGo: go,
      child: _location.render(
        handleSystemBack: false,
        navigatorKey: _navigatorKey,
      ),
    );
  }

  // Route a push to its level: a top-level route to the root (full-page above
  // the shell), a tab route into the active tab's stack.
  Future<void> push(RakuRoute route) =>
      (tree.isRootLevel(route) ? _location.root : _location.activeLeafStack)
          .push(route);

  Future<void> go(RakuRoute route) => _navigate(route, honourGuards: false);

  @override
  Future<void> setNewRoutePath(RakuRoute configuration) =>
      _navigate(configuration, honourGuards: true);

  Future<void> _navigate(RakuRoute route, {required bool honourGuards}) async {
    final ticket = ++_ticket;
    final matches = await _resolveLocation(route);
    if (ticket != _ticket) return; // superseded by a newer navigation
    // A platform URL change (browser back/forward) that would remove a guarded
    // page is vetoed like the back button: run onPopBlocked and keep the
    // location — the Router then re-reports it, so the address bar snaps back.
    if (honourGuards) {
      final blocked = _location.blockingGuard(matches);
      if (blocked != null) {
        _runPopBlocked(blocked.guard, blocked.stack);
        notifyListeners();
        return;
      }
    }
    // Reconcile the live tree to the resolved location *in place* rather than
    // rebuilding it: the active path follows the URL while the other branches —
    // and every unchanged page — keep their state, so a browser back/forward
    // doesn't reset the inactive tabs.
    _location.reconcile(matches);
    notifyListeners();
  }

  // Resolves [route] to the location to show. Redirects apply on URL entry too,
  // so a RouteRedirect reached via a deep link behaves like one reached via
  // push — and the location is built from the *resolved* route, so a tab route
  // that redirects to a full-page one lands above the shell.
  //
  // A URL rebuilds the whole ancestor chain, so every route on that path is
  // checked, not only the leaf: a deep link to `/admin/users/1` must not slip
  // past a sign-in redirect declared on `/admin`. The outermost ancestor that
  // redirects wins, and the result is re-checked (bounded, like any chain).
  Future<List<RouteMatch>> _resolveLocation(RakuRoute route) async {
    var target = await resolveRedirects(route);
    for (var hop = 0;; hop++) {
      final matches = tree.match(tree.locationOf(target))!;
      RakuRoute? redirected;
      for (final step in _activePath(matches)) {
        if (step is! RouteRedirect) continue;
        final resolved = await resolveRedirects(step);
        if (resolved != step) {
          redirected = resolved;
          break;
        }
      }
      // Done — or, in release, stop at the last location of a runaway chain.
      if (redirected == null || hop == _maxAncestorRedirects) {
        assert(
          redirected == null,
          'Raku: redirect loop detected while resolving ${route.runtimeType}.',
        );
        return matches;
      }
      target = redirected;
    }
  }

  static const int _maxAncestorRedirects = 16;

  // Runs [guard]'s onPopBlocked with a context inside [stack]'s navigator, so a
  // confirming `context.pop()` pops that stack (the guarded page's own).
  void _runPopBlocked(RouteGuard guard, RouteStack stack) {
    final context =
        navigatorOfStack(stack)?.context ?? _navigatorKey.currentContext;
    if (context != null) guard.onPopBlocked(context);
  }

  @override
  Future<bool> popRoute() {
    // The discrete system back button is routed here (the nested navigators run
    // with handleSystemBack: false). An overlay shown imperatively — a dialog,
    // bottom sheet, menu — sits above the pages, so it is dismissed first: the
    // root navigator's (it covers everything), then each active branch's.
    for (final stack in _location.activeStacks) {
      final dismissed = popOverlay(stack);
      if (dismissed != null) return dismissed;
    }
    final stack = _location.activeLeafStack;
    final top = stack.current;
    // Honour a guarded leaf the same way every other pop path does: veto, and
    // run onPopBlocked (e.g. a confirm dialog) — matching `context.pop()`.
    if (top is RouteGuard && !top.canPop) {
      _runPopBlocked(top, stack);
      return SynchronousFuture<bool>(false);
    }
    return stack.pop();
  }

  @override
  void dispose() {
    _location.removeListener(_handleChange);
    _location.dispose();
    current.dispose();
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
    // The URL is untrusted (address bar, deep link): an unknown *or* malformed
    // one falls back to onUnknown instead of throwing (see RouteTree.match).
    final matched = _tree.match(uri);
    return SynchronousFuture<RakuRoute>(
      matched == null ? _onUnknown(uri) : _leafOf(matched),
    );
  }

  @override
  RouteInformation? restoreRouteInformation(RakuRoute configuration) =>
      RouteInformation(uri: _tree.locationOf(configuration));
}
