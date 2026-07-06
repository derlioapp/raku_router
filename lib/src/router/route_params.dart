/// Read-only access to the parameters captured from a matched URL — the path
/// `:params` and the `?query` parameters.
///
/// Passed to a route's `parse` function so it can build a typed route object,
/// e.g. `(p) => Note(p('id'))` or `(p) => Search(p.query('q') ?? '')`.
class RouteParams {
  /// Wraps the captured path [_values] and the URL's [_query] parameters.
  RouteParams(this._values, [this._query = const <String, String>{}]);

  final Map<String, String> _values;
  final Map<String, String> _query;

  /// The value of path parameter [name]. Asserts in debug if it is absent.
  String call(String name) {
    final value = _values[name];
    assert(value != null, 'Raku: no path parameter named "$name".');
    return value ?? '';
  }

  /// The value of path parameter [name], or null if it was not present.
  String? optional(String name) => _values[name];

  /// Path parameter [name] parsed as an `int` (throws if it isn't one).
  int asInt(String name) => int.parse(call(name));

  /// Path parameter [name] as an `int`, or null if absent / not an int.
  int? optionalInt(String name) {
    final value = _values[name];
    return value == null ? null : int.tryParse(value);
  }

  /// The `?query` parameter [name], or null if it was not present.
  String? query(String name) => _query[name];

  /// The catch-all remainder for a wildcard (`*`) route — the unmatched path
  /// tail (e.g. `garbage/x` for `/feed/*` matched against `/feed/garbage/x`),
  /// or `''` when the wildcard matched no extra segments. Use it to build a
  /// typed not-found route: `route('*', (p) => NotFound(p.rest), …)`.
  String get rest => _values['*'] ?? '';
}

/// The URL-shaped value a route encodes to: its path `:params` and, optionally,
/// its `?query` parameters. The inverse of what a node's `parse` reads.
///
/// Returned from a `route(..., encode:)` function to build a route's URL when a
/// single prop can't be auto-derived — a multi-parameter path, or one that
/// carries query state:
///
/// ```dart
/// route('/users/:org/:id', (p) => Member(p('org'), p('id')),
///     (m) => MemberScreen(m), encode: (m) => RoutePath({'org': m.org, 'id': m.id}));
///
/// route('/search', (p) => Search(p.query('q') ?? ''), (s) => SearchScreen(s),
///     encode: (s) => RoutePath(const {}, query: {'q': s.term}));
/// ```
class RoutePath {
  /// Builds a location from its path [params] and optional [query] parameters.
  const RoutePath(this.params, {this.query = const <String, String>{}});

  /// Values for the template's `:param` segments, keyed by name.
  final Map<String, String> params;

  /// Optional `?query` parameters to append to the URL.
  final Map<String, String> query;
}
