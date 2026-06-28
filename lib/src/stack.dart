import 'dart:async';

import 'package:flutter/foundation.dart';

import 'route.dart';

/// One entry on a [RouteStack]: a route plus a process-unique id used to derive
/// a stable [pageKey].
@immutable
class RakuEntry {
  /// Wraps [route] with a fresh process-unique [id].
  RakuEntry(this.route) : id = _nextId++;

  static int _nextId = 0;

  /// Process-unique id; survives rebuilds, distinguishes otherwise-equal routes.
  final int id;

  /// The route this entry presents.
  final RakuRoute route;

  /// Stable key for the [Page] that renders this entry.
  ValueKey<String> get pageKey => ValueKey<String>('raku_router#$id');
}

/// A reactive navigation stack.
///
/// This is the heart of Raku: a mutable list of routes exposed as a
/// [ValueListenable]. It depends only on `flutter/foundation`, so it carries no
/// state-management or UI dependency — wrap it in a `signal`, `ValueListenable`
/// builder, provider, or anything else.
///
/// Mutations honour [RouteRedirect] (on push/replace) and [RouteGuard] (on pop).
class RouteStack extends ChangeNotifier
    implements ValueListenable<List<RakuRoute>> {
  /// Creates a stack with a single initial [route].
  RouteStack(RakuRoute route) : _entries = <RakuEntry>[RakuEntry(route)];

  /// Creates a stack pre-populated with [routes] (must be non-empty).
  RouteStack.fromRoutes(List<RakuRoute> routes)
      : assert(
          routes.isNotEmpty,
          'Raku: a RouteStack needs at least one route.',
        ),
        _entries = routes.map(RakuEntry.new).toList();

  final List<RakuEntry> _entries;

  /// The current entries, bottom-to-top. Mainly for the view layer.
  List<RakuEntry> get entries => List<RakuEntry>.unmodifiable(_entries);

  @override
  List<RakuRoute> get value =>
      List<RakuRoute>.unmodifiable(_entries.map((e) => e.route));

  /// The route currently on top.
  RakuRoute get current => _entries.last.route;

  /// Number of routes on the stack.
  int get length => _entries.length;

  /// Whether there is more than one route (i.e. a pop is possible).
  bool get canPop => _entries.length > 1;

  /// Pushes [route] onto the stack, following any [RouteRedirect].
  ///
  /// Completes synchronously (notifying listeners in the same call) when [route]
  /// is not a [RouteRedirect] — the common case — so the UI reflects the push
  /// without waiting a microtask.
  Future<void> push(RakuRoute route) {
    final resolved = _resolve(route);
    if (resolved is RakuRoute) {
      _append(resolved);
      return SynchronousFuture<void>(null);
    }
    return resolved.then(_append);
  }

  void _append(RakuRoute route) {
    _entries.add(RakuEntry(route));
    notifyListeners();
  }

  /// Pops the top route, honouring its [RouteGuard].
  ///
  /// Returns `true` if a route was removed, `false` if the pop was blocked
  /// (guard, or already at the root).
  ///
  /// raku_router does **not** thread a result back through `pop`/`push`: navigation
  /// is declarative, so a result flows back through your app state (a shared
  /// listenable, a callback on the route), not an awaited future.
  ///
  /// Returns a [Future] to satisfy the framework's `popRoute` / `maybePop`
  /// contract, but always completes synchronously (the guard check is sync), so
  /// the stack reflects the pop in the same call — like [push] / [replace].
  Future<bool> pop() {
    if (_entries.length <= 1) return SynchronousFuture<bool>(false);
    final top = _entries.last.route;
    if (top is RouteGuard && !top.canPop) return SynchronousFuture<bool>(false);
    _entries.removeLast();
    notifyListeners();
    return SynchronousFuture<bool>(true);
  }

  /// Replaces the top route with [route] (following any [RouteRedirect]).
  ///
  /// Like [push], completes synchronously when [route] is not a [RouteRedirect].
  Future<void> replace(RakuRoute route) {
    final resolved = _resolve(route);
    if (resolved is RakuRoute) {
      _replaceTop(resolved);
      return SynchronousFuture<void>(null);
    }
    return resolved.then(_replaceTop);
  }

  void _replaceTop(RakuRoute route) {
    _entries[_entries.length - 1] = RakuEntry(route);
    notifyListeners();
  }

  /// Clears the stack down to a single [route].
  ///
  /// A no-op when the stack is *already* just that route — re-rooting to where
  /// you already are (e.g. tapping the current folder in the sidebar again)
  /// shouldn't tear down and rebuild the screen.
  void reset(RakuRoute route) {
    if (_entries.length == 1 && current.sameDestination(route)) return;
    setRoutes(<RakuRoute>[route]);
  }

  /// Replaces the entire stack with [routes] (must be non-empty).
  void setRoutes(List<RakuRoute> routes) {
    assert(
      routes.isNotEmpty,
      'Raku: a RouteStack needs at least one route.',
    );
    _entries
      ..clear()
      ..addAll(routes.map(RakuEntry.new));
    notifyListeners();
  }

  /// Updates the stack to [routes], reusing the existing entry — and thus its
  /// page key and element state — for the longest unchanged prefix (matched by
  /// [RakuRoute.sameDestination]); fresh entries back the rest.
  ///
  /// Unlike [setRoutes], which re-keys every entry, this is how a platform URL
  /// change (browser back/forward, a deep link) is applied without tearing down
  /// pages that didn't change: a shell, or a screen still present at the same
  /// depth, keeps its state instead of being rebuilt from scratch.
  void reconcileRoutes(List<RakuRoute> routes) {
    assert(
      routes.isNotEmpty,
      'Raku: a RouteStack needs at least one route.',
    );
    final next = <RakuEntry>[];
    var diverged = false;
    for (var i = 0; i < routes.length; i++) {
      if (!diverged &&
          i < _entries.length &&
          _entries[i].route.sameDestination(routes[i])) {
        next.add(_entries[i]);
      } else {
        diverged = true;
        next.add(RakuEntry(routes[i]));
      }
    }
    _entries
      ..clear()
      ..addAll(next);
    notifyListeners();
  }

  /// Pops routes until [predicate] matches the top route (never empties the
  /// stack). Guards are not consulted for the intermediate pops.
  void popUntil(bool Function(RakuRoute route) predicate) {
    var changed = false;
    while (_entries.length > 1 && !predicate(_entries.last.route)) {
      _entries.removeLast();
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Removes the entry backing [pageKey], if still present.
  ///
  /// The view calls this from `Navigator.onDidRemovePage` so the stack stays in
  /// sync when the framework removes a page (e.g. an imperative
  /// `Navigator.pop` inside a screen). Idempotent and never removes the root.
  void handlePageRemoved(Object? pageKey) {
    final index = _entries.indexWhere((e) => e.pageKey == pageKey);
    if (index <= 0) return;
    _entries.removeAt(index);
    notifyListeners();
  }

  /// Follows [route]'s [RouteRedirect] chain (loop-protected) to its final
  /// destination. `push`/`replace` apply this automatically; the router uses it
  /// to resolve a route entered via a URL before showing it.
  Future<RakuRoute> resolve(RakuRoute route) =>
      Future<RakuRoute>.value(_resolve(route));

  // Returns synchronously for a non-redirect route (the common case); only a
  // route that mixes in RouteRedirect follows the (async) chain.
  FutureOr<RakuRoute> _resolve(RakuRoute route) {
    if (route is! RouteRedirect) return route;
    return _resolveRedirect(route);
  }

  Future<RakuRoute> _resolveRedirect(RakuRoute route) async {
    var current = route;
    final visited = <RakuRoute>[];
    while (current is RouteRedirect) {
      final next = await current.redirect();
      if (next == null || next.sameDestination(current)) break;
      if (visited.any((seen) => seen.sameDestination(next))) {
        assert(
          false,
          'Raku: redirect loop detected ending at ${next.runtimeType}.',
        );
        break;
      }
      visited.add(current);
      current = next;
    }
    return current;
  }
}
