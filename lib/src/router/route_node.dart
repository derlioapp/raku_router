import 'package:flutter/widgets.dart';

import '../branch.dart';
import '../route.dart';
import 'path_pattern.dart';
import 'route_params.dart';

/// Builds the shell around the tabs — e.g. a `Scaffold` with a bottom bar or a
/// side menu. [child] is the active tab's content; [tabs] drives tab switching.
typedef RouteShellBuilder = Widget Function(
  BuildContext context,
  BranchedRouteStack tabs,
  Widget child,
);

/// A node of the route tree. Either a [ScreenNode] (a URL ↔ a typed screen, with
/// optional nested children) or a [TabsNode] (a shell over preserved parallel
/// branches). Build them with [route] and [tabs].
sealed class RouteNode {}

/// A screen route: a URL segment bound to a typed route and its screen, with
/// optional nested [children]. Created with [route].
///
/// Nesting is structural — a child's URL extends its parent's, and a deep URL
/// produces the whole ancestor chain as the navigation stack, so a deep link
/// reconstructs back history the way a web router does.
class ScreenNode extends RouteNode {
  /// Prefer the [route] helper, which infers [type] and wraps the typed screen.
  ScreenNode({
    required this.path,
    required this.type,
    required this.parse,
    required this.screen,
    this.encode,
    this.transition,
    this.title,
    this.children = const <ScreenNode>[],
  });

  /// Absolute (`/feed`) or relative to its parent (`notes/:id`).
  final String path;

  /// The concrete route type this node produces.
  final Type type;

  /// Builds the typed route from the captured URL parameters.
  final RakuRoute Function(RouteParams params) parse;

  /// Builds the screen for a route of this node's [type].
  final Widget Function(RakuRoute route) screen;

  /// Builds this route's URL parts (path `:params` + optional `?query`) — the
  /// inverse of [parse]. When null, the URL is auto-derived from the route's
  /// single prop (only valid for a path with zero or one `:param`).
  final RoutePath Function(RakuRoute route)? encode;

  /// Optional transition for this node's page.
  final RouteTransitionsBuilder? transition;

  /// Builds the browser tab / task-switcher title for a route of this node's
  /// [type], or null to leave the title unchanged.
  final String Function(RakuRoute route)? title;

  /// Nested screens whose URLs extend this one (and stack on top of it).
  final List<ScreenNode> children;
}

/// A tabs shell: preserved parallel [branches] rendered through a [shell]. The
/// active branch is determined by the URL; the others keep their state. Created
/// with [tabs]; a `TabsNode` may itself appear inside a branch (nested tabs).
class TabsNode extends RouteNode {
  /// Wraps [branches] (each a list of [RouteNode]s) in a [shell].
  TabsNode({required this.shell, required this.branches})
      : assert(
          branches.isNotEmpty,
          'Raku: tabs() needs at least one branch.',
        );

  /// Builds the chrome (bottom bar / side menu) around the active branch.
  final RouteShellBuilder shell;

  /// One sub-tree per tab.
  final List<List<RouteNode>> branches;
}

/// Declares one screen route: its [path], how to rebuild it from that URL, how
/// to render it, and any nested [children].
///
/// [encode] is the inverse of [parse] — give it when the URL has more than one
/// `:param`, or carries `?query` state, so it can't be auto-derived from the
/// route's single prop. Without it, a zero/one-param path's URL is built
/// automatically.
///
/// A trailing `*` makes a **catch-all** (wildcard) route — a typed 404 for any
/// URL not matched by a concrete route. Nest it under a section for a
/// subtree-scoped not-found, or put it at the top level for a global one; the
/// most specific catch-all wins, and a concrete route always beats a wildcard.
/// The unmatched tail arrives via [RouteParams.rest], so the caught URL
/// round-trips:
///
/// ```dart
/// route('*', (p) => NotFound(p.rest), (n) => NotFoundScreen(path: n.path));
/// ```
///
/// [title] sets the browser tab / task-switcher label while a route of this
/// node is the active leaf — derive it from the route so detail pages read well:
/// `route('notes/:id', …, title: (n) => 'Note ${n.id}')`.
ScreenNode route<R extends RakuRoute>(
  String path,
  R Function(RouteParams params) parse,
  Widget Function(R route) screen, {
  RoutePath Function(R route)? encode,
  List<ScreenNode> children = const <ScreenNode>[],
  RouteTransitionsBuilder? transition,
  String Function(R route)? title,
}) {
  return ScreenNode(
    path: path,
    type: R,
    parse: parse,
    screen: (route) => screen(route as R),
    encode: encode == null ? null : (route) => encode(route as R),
    transition: transition,
    title: title == null ? null : (route) => title(route as R),
    children: children,
  );
}

/// Declares a tabs shell over preserved parallel [branches].
RouteNode tabs({
  required RouteShellBuilder shell,
  required List<List<RouteNode>> branches,
}) =>
    TabsNode(shell: shell, branches: branches);

/// A resolved navigation entry: a screen or a tabs shell. A matched URL is a
/// *stack* of these (`List<RouteMatch>`).
sealed class RouteMatch {}

/// A matched screen and its typed route.
class ScreenMatch extends RouteMatch {
  /// Pairs [node] with the [route] it produced.
  ScreenMatch(this.node, this.route);

  /// The node that matched.
  final ScreenNode node;

  /// The typed route built from the URL.
  final RakuRoute route;
}

/// A matched tabs shell: which branch is [activeBranch] and each branch's stack.
class TabsMatch extends RouteMatch {
  /// Builds a tabs match.
  TabsMatch(this.node, this.activeBranch, this.branches);

  /// The tabs node.
  final TabsNode node;

  /// The index of the branch the URL resolved into.
  final int activeBranch;

  /// Each branch's resolved stack (the active one from the URL, the rest at
  /// their initial route).
  final List<List<RouteMatch>> branches;
}

/// A compiled route tree: matches a URL to the **stack** it represents (with
/// tabs resolved recursively), and a route back to its URL.
class RouteTree {
  /// Compiles [roots] (and descendants), indexing every screen by type.
  RouteTree(this.roots) {
    assert(
      roots.whereType<TabsNode>().length <= 1,
      'Raku: a route tree supports at most one top-level tabs() shell '
      '(the rest are silently unreachable). Nest additional shells inside a '
      'branch, or model the section as full-page routes above the shell.',
    );
    _index(roots, '');
  }

  /// The top-level nodes.
  final List<RouteNode> roots;

  final Map<Type, PathPattern> _patternByType = <Type, PathPattern>{};
  final Map<Type, ScreenNode> _nodeByType = <Type, ScreenNode>{};
  final Set<Type> _rootLevelTypes = <Type>{};

  void _index(List<RouteNode> nodes, String parent, {bool inTabs = false}) {
    for (final node in nodes) {
      switch (node) {
        case ScreenNode():
          final full = _join(parent, node.path);
          _patternByType[node.type] = PathPattern(full);
          _nodeByType[node.type] = node;
          if (!inTabs) _rootLevelTypes.add(node.type);
          _index(node.children, full, inTabs: inTabs);
        case TabsNode():
          for (final branch in node.branches) {
            _index(branch, parent, inTabs: true);
          }
      }
    }
  }

  /// Whether [route] is a **top-level** route (above any tabs shell) — used to
  /// decide whether a push goes to the root or into the active tab.
  bool isRootLevel(RakuRoute route) =>
      _rootLevelTypes.contains(route.runtimeType);

  /// Resolves [uri] to a stack of matches, or null if nothing matches. A
  /// top-level tabs shell is always the base of the stack (so a full-page route
  /// sits above it); the others stack on top.
  ///
  /// Matching runs in two passes: a **strict** pass that ignores catch-all
  /// (`*`) nodes, then a **catch-all** pass. So a concrete route always beats a
  /// wildcard, and the deepest matching wildcard (a subtree `/feed/*`) beats a
  /// shallower one (a top-level `/*`); if neither pass matches, `match` returns
  /// null and the caller's global `onUnknown` takes over.
  List<RouteMatch>? match(Uri uri) =>
      _matchAt(uri, allowCatchAll: false) ?? _matchAt(uri, allowCatchAll: true);

  List<RouteMatch>? _matchAt(Uri uri, {required bool allowCatchAll}) {
    final shell = roots.whereType<TabsNode>().firstOrNull;

    // A URL inside the shell resolves to just the shell (with the active branch).
    if (shell != null) {
      final inside = _matchTabs(shell, '', uri, allowCatchAll);
      if (inside != null) return inside;
    }

    // Otherwise try the top-level screens; a full-page screen stacks above the
    // shell (kept at its initial state underneath).
    for (final node in roots) {
      if (node is ScreenNode) {
        final screenStack = _matchScreen(node, '', uri, allowCatchAll);
        if (screenStack != null) {
          return <RouteMatch>[
            if (shell != null) _tabsInitial(shell, ''),
            ...screenStack,
          ];
        }
      }
    }
    return null;
  }

  List<RouteMatch>? _matchNodes(
    List<RouteNode> nodes,
    String parent,
    Uri uri,
    bool allowCatchAll,
  ) {
    for (final node in nodes) {
      final matched = switch (node) {
        ScreenNode() => _matchScreen(node, parent, uri, allowCatchAll),
        TabsNode() => _matchTabs(node, parent, uri, allowCatchAll),
      };
      if (matched != null) return matched;
    }
    return null;
  }

  List<RouteMatch>? _matchScreen(
    ScreenNode node,
    String parent,
    Uri uri,
    bool allowCatchAll,
  ) {
    final chain = _screenChain(node, parent, uri, allowCatchAll);
    if (chain == null) return null;
    final params = RouteParams(chain.params, uri.queryParameters);
    return <RouteMatch>[
      for (final n in chain.nodes) ScreenMatch(n, n.parse(params)),
    ];
  }

  ({List<ScreenNode> nodes, Map<String, String> params})? _screenChain(
    ScreenNode node,
    String parent,
    Uri uri,
    bool allowCatchAll,
  ) {
    final full = _join(parent, node.path);
    // Children first, so a deeper concrete match wins over this node.
    for (final child in node.children) {
      final deeper = _screenChain(child, full, uri, allowCatchAll);
      if (deeper != null) {
        return (
          nodes: <ScreenNode>[node, ...deeper.nodes],
          params: deeper.params
        );
      }
    }
    final pattern = _patternByType[node.type]!;
    // A catch-all node only matches in the second (catch-all) pass, so any
    // concrete route — at this level or deeper — is preferred.
    if (pattern.isCatchAll && !allowCatchAll) return null;
    final captured = pattern.match(uri.path);
    if (captured != null) return (nodes: <ScreenNode>[node], params: captured);
    return null;
  }

  List<RouteMatch>? _matchTabs(
    TabsNode node,
    String parent,
    Uri uri,
    bool allowCatchAll,
  ) {
    for (var i = 0; i < node.branches.length; i++) {
      final inner = _matchNodes(node.branches[i], parent, uri, allowCatchAll);
      if (inner != null) {
        return <RouteMatch>[
          TabsMatch(node, i, <List<RouteMatch>>[
            for (var j = 0; j < node.branches.length; j++)
              if (j == i) inner else _branchInitial(node.branches[j], parent),
          ]),
        ];
      }
    }
    return null;
  }

  TabsMatch _tabsInitial(TabsNode node, String parent) => TabsMatch(
        node,
        0,
        <List<RouteMatch>>[
          for (final branch in node.branches) _branchInitial(branch, parent),
        ],
      );

  List<RouteMatch> _branchInitial(List<RouteNode> branch, String parent) {
    final first = branch.first;
    switch (first) {
      case ScreenNode():
        return <RouteMatch>[
          ScreenMatch(first, first.parse(RouteParams(const {}))),
        ];
      case TabsNode():
        return <RouteMatch>[_tabsInitial(first, parent)];
    }
  }

  /// Whether this tree has a screen node for [route]'s type.
  bool handles(RakuRoute route) =>
      _patternByType.containsKey(route.runtimeType);

  /// The URL for [route], built from its node's full pattern.
  ///
  /// Uses the node's `encode:` when given (multi-param or query-carrying routes);
  /// otherwise auto-derives the path from the route's single prop.
  Uri locationOf(RakuRoute route) {
    final pattern = _patternFor(route);
    final encode = _nodeFor(route).encode;
    if (encode != null) {
      final location = encode(route);
      final uri = Uri.parse(pattern.fill(location.params));
      return location.query.isEmpty
          ? uri
          : uri.replace(queryParameters: location.query);
    }
    return Uri.parse(pattern.fill(_paramsFromProps(pattern, route)));
  }

  /// The screen widget for [route].
  Widget screen(BuildContext context, RakuRoute route) =>
      _nodeFor(route).screen(route);

  /// The transition for [route], or null to use the host default.
  RouteTransitionsBuilder? transitionFor(RakuRoute route) =>
      _nodeFor(route).transition;

  /// The browser tab / task-switcher title for [route], or null when its node
  /// declares no `title:` (or [route] has no node, e.g. a shell sentinel).
  String? titleFor(RakuRoute route) =>
      _nodeByType[route.runtimeType]?.title?.call(route);

  PathPattern _patternFor(RakuRoute route) {
    final pattern = _patternByType[route.runtimeType];
    if (pattern != null) return pattern;
    throw AssertionError(
      'Raku: no route tree node for ${route.runtimeType}. '
      'Add a `route(...)` for it.',
    );
  }

  ScreenNode _nodeFor(RakuRoute route) {
    final node = _nodeByType[route.runtimeType];
    if (node != null) return node;
    throw AssertionError(
      'Raku: no route tree node for ${route.runtimeType}. '
      'Add a `route(...)` for it.',
    );
  }

  // Single-parameter convenience: one prop fills one :param; multi-param routes
  // need an explicit encode.
  Map<String, String> _paramsFromProps(
    PathPattern pattern,
    RakuRoute route,
  ) {
    final names = pattern.parameters;
    final props = route.props;
    assert(
      names.length <= 1,
      'Raku: ${route.runtimeType}\'s URL "${pattern.template}" has '
      '${names.length} parameters; auto-deriving them from props is only safe '
      'for one. Give this route an explicit `encode:`.',
    );
    assert(
      names.length == props.length,
      'Raku: ${route.runtimeType} has ${props.length} props but its URL '
      '"${pattern.template}" needs ${names.length}.',
    );
    return <String, String>{
      for (var i = 0; i < names.length; i++) names[i]: '${props[i]}',
    };
  }

  static String _join(String parent, String child) {
    if (child.startsWith('/')) return child;
    if (parent.isEmpty || parent == '/') return '/$child';
    return '$parent/$child';
  }
}
