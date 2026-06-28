# raku_router — what works, and is tested

A list of the capabilities the test suite **proves**. Every item below has a
green test; the package runs at **100% line coverage** on `lib/src`, warning-free
`dart doc`, and a CI guard that forbids Material/Cupertino in `lib/`.

> The router is a nested **route tree** — `raku(routes: [route()/tabs()])` is
> the single entry point. Items tagged _(tree)_ are the web-grade routing model;
> the rest are the core primitives the tree is built on. Test files are named in
> parentheses.

## Web-grade deep linking _(tree)_

- **A URL's path structure reconstructs the navigation stack.** Deep-linking to
  `/feed/notes/42` rebuilds `[Feed, Note(42)]`, so **back returns to Feed**, not a
  rootless screen — end-to-end through the real router (`raku_router`), for both
  a plain screen tree **and a tab branch**. (`route_node_test`, `tree_router_test`,
  `tree_tabs_test`)
- **A deep link reconstructs the stack *inside the correct tab*** — `/feed/notes/42`
  selects the feed tab and rebuilds its branch stack to `[Feed, Note(42)]`; back
  pops within the tab. (`tree_tabs_test`)
- **Switching tabs rewrites the address bar** — `tabs.go(1)` makes the active
  configuration (and URL) the other branch's location. (`tree_tabs_test`)
- **Route → URL is automatic and round-trips.** `Note('42')` ↔ `/feed/notes/42`
  via the node's full path; parse/restore round-trip. (`route_node_test`,
  `tree_router_test`)
- **Multi-`:param` and `?query` URLs round-trip via `encode:`** — `RoutePath`
  builds both a multi-parameter path and its query string, the inverse of `parse`,
  so query-backed routes don't lose state on route → URL. (`route_node_test`)
- **Arbitrary nesting depth** — a child's URL extends its parent's; the whole
  ancestor chain becomes the stack. (`route_node_test`)
- **Typed path params, no stringly access** — `(p) => Note(p('id'))`; plus
  `p.asInt('id')`, `p.optionalInt`, and `?query` via `p.query('q')`.
  (`route_params_test`, `route_node_test`)
- **Unknown URLs fall back** through `onUnknown`. (`tree_router_test`)
- **No code generation** — routes are sealed classes + an exhaustive `switch`.

## Tabs (preserved, parallel branches) _(tree)_

- **Each tab keeps its own back stack** across switches; switching away and back
  returns you exactly where you were. (`branch_test`, `branched_view_test`)
- **A deep link resolves to the right tab and rebuilds that branch's stack**; on a
  *cold* link the other branches sit at their initial route. (`route_node_test`)
- **State survives platform URL changes** — a browser back/forward (or any
  platform URL change) reconciles the live tree in place: the active path follows
  the URL while inactive tabs keep their in-app history and unchanged screens keep
  their element state (proven with a stateful counter that would reset on a
  rebuild). (`reconcile_state_test`)
- **Nested tabs** — tabs inside a tab — resolve recursively and **render, switch,
  and preserve** their inner state. (`route_node_test`)
- **Tabs build lazily and are then cached** — a tab's `Navigator` is created the
  first time it is shown (not up front), then kept alive: revisiting it, or
  navigating in another tab, never rebuilds it (proven by build-counting).
  (`branched_view_test`)
- **Nested navigation animates only the content area** — the shell (bottom bar
  *or* side menu) stays fixed; proven for both layouts by measuring positions.
  (`branched_view_test`)
- **Each tab gets its own `HeroController`**, so heroes work within a tab.
  (`branched_view_test`)
- **`tabs.go(index)`** switches tabs; `reset(initial)` re-roots a tab (the
  primitive behind "tap the active tab → pop to root").

## Full-page routes over a tab shell _(tree)_

- **Top-level routes sit in a root navigator above the shell** — they cover the
  bar/menu and the whole page animates; the tab shell stays underneath at its
  initial state. Proven through the real tree router: `context.push` of a
  top-level route covers the shell and back returns to the preserved tab.
  (`route_node_test`, `tree_tabs_test`)
- **`context.push(route)` routes to the right level automatically** from where the
  route is declared (in a tab vs. top-level) — a tab route lands in the active
  tab's stack, a top-level route lands full-page above the shell.
  (`tree_tabs_test`)
- **Deep link + redirect compose** — a tab route that `RouteRedirect`s to a
  full-page route lands above the shell. (`tree_tabs_test`)

## Typed, object-based navigation

- **Navigate by value, never by string** — `context.push(const Note('42'))`,
  `context.pop()`, `context.replace(...)`. (`stack_view_test`, `route_kit_test`)
- **Reactive stack** (`RouteStack` is a `ValueListenable<List<route>>`): push /
  pop / replace / reset / setRoutes / popUntil, all notify listeners.
  (`raku_router_test`)
- **`raku(onNavigation:)`** reports the active leaf as a typed `RakuRoute`
  after every change that moves it (push, pop, tab switch, browser back/forward),
  once per change, and not for the initial route. (`on_navigation_test`)
- **Value equality from `(runtimeType, props)`** with separate process-unique page
  identity, so equal routes coexist on the stack. (`raku_router_test`)
- **`reset` is idempotent** — re-rooting to the route you're already on doesn't
  tear the screen down. (`raku_router_test`)

## Guards, redirects (control flow on the route)

- **Guards integrate with `PopScope`** — a synchronous `canPop` is honoured by the
  **predictive-back gesture, an imperative `Navigator.pop`, the system back
  button, and `context.pop()`**; `onPopBlocked` confirms (e.g. a dialog) and
  `rebuildOn` re-evaluates as state changes. In Router (deep-link) mode the
  discrete system back button is vetoed by a guard **and runs `onPopBlocked`**,
  so the confirm hook fires on every back path. (`guard_popscope_test`,
  `system_back_test`, `tree_router_test`, `router_system_back_test`)
- **Redirects** are followed and **loop-protected**; they resolve on push *and* on
  deep-link entry — including a tab route that redirects to a full-page route.
  (`redirect_guard_test`, `tree_router_test`, `tree_tabs_test`)
- A vetoed pop is **control flow, not an error** (returns `false`).
  (`error_contract_test`)

## Premium transitions

- **`slideIn` is the default** — direction-parametric (`from:` left/right/top/
  bottom), Material 3 emphasized easing on the incoming page, iOS-style parallax +
  subtle dim on the outgoing one. It owns its `CurvedAnimation`s (created once,
  disposed). (`premium_slide_test`, `route_kit_test`)
- **Per-route and global override**; disable with `RakuTransitions.none`.
  (`route_kit_test`, `stack_view_test`)
- Also ships `none`, `fade`, `slide`, `riseUp`. (`page_transition_test`)
- A route's own `RouteTransition` mixin overrides everything. (`page_transition_test`)

## Correctness & platform

- **State restoration** — with `restorationScopeId`, the tree router restores the
  navigation location across process death; a fresh delegate is re-fed the saved
  URL and reconstructs the stack (proven with `restartAndRestore`, plus a negative
  case without restoration). The active tab is restored too. (`restoration_test`)
- **System back** pops the active stack and **a guard vetoes it**.
  (`system_back_test`)
- **`onDidRemovePage` keeps the stack in sync** after an imperative
  `Navigator.pop`. (`page_transition_test`)
- **Material/Cupertino-free `lib/`** (CI-guarded) — drops into any design system.
- **Clear, `Raku:`-prefixed assertion contract** for misuse (empty stack,
  out-of-range tab index, missing scope, multi-param URL without `encode`, more
  than one top-level `tabs()` shell). (`error_contract_test`, `route_node_test`)
- **No leaks** — controllers, HeroControllers, and listeners are disposed; proven
  by the test harness's leak checks.
