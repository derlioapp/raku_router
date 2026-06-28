/// Raku — a tiny, code-generation-free, UI-agnostic router for Flutter.
///
/// * **Type-safe, no codegen** — routes are plain sealed classes; an exhaustive
///   `switch` is your route table.
/// * **Nested navigation built in** — [BranchedRouteStack] gives each tab its
///   own persistent back stack; [tabs] nodes nest arbitrarily.
/// * **Deep linking from a declarative route tree** — `raku(routes: [...])`
///   maps a URL's *structure* to a typed navigation stack, both ways, with no
///   hand-written parsing.
/// * **No state-management or design-system dependency** — the core only needs
///   `flutter`. Inject your own pages/transitions.
///
/// ## Naming convention
///
/// Two deliberate families: the **core vocabulary** you compose with reads as
/// plain nouns — [RouteStack], [RouteStackView], [RouteStackScope],
/// [BranchedRouteStack], [BranchedStackView], [RouteBranch], and the route
/// mixins [RouteGuard] / [RouteRedirect] / [RouteTransition]. The **framework
/// plumbing** you rarely name directly carries the `Raku` prefix —
/// [RakuRoute], [RakuPage], [RakuTransitions], [RakuEntry], and
/// the `Raku*` typedefs. (`RakuGuard` would only add noise.)
///
/// ## Errors & assertions
///
/// Misuse is treated as a programmer error: an empty stack, an out-of-range
/// branch index, or a missing [RouteStackScope] trips an `assert` in debug
/// builds with a `Raku:`-prefixed, actionable message. In release builds
/// these assertions are stripped — where a sane fallback exists it is taken
/// rather than crashing: a redirect loop stops at the last resolved route
/// instead of spinning. Guards and redirects are *control flow*, not errors —
/// a vetoed pop simply returns `false`.
library;

// Public API. Deep linking is driven by the declarative route tree
// (`raku(routes: [route()/tabs()])`); importing raku_router never forces the
// Router machinery on until you build a config.
export 'src/branch.dart';
export 'src/page.dart';
export 'src/route.dart';
export 'src/router/route_node.dart';
export 'src/router/route_params.dart';
export 'src/router/tree_router.dart';
export 'src/stack.dart';
export 'src/stack_view.dart';
