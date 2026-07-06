## 0.2.0

Additive features on the way to a stable `1.0` — no breaking changes.

- **Navigator observers** — `raku(observers: …)` attaches `NavigatorObserver`s
  (`FirebaseAnalyticsObserver`, `SentryNavigatorObserver`, `RouteObserver`, …)
  to the root and every tab-branch navigator. It's a *factory* (`() => [...]`):
  one observer instance can attach to only one `Navigator`, so each navigator
  gets fresh instances — and an observer therefore sees in-tab pushes too.
- **Catch-all routes (typed 404)** — a trailing `*` in a `route(...)` path
  matches any URL a concrete route doesn't. Nest it for a subtree-scoped
  not-found (shown inside the tab), or put it at the top level for a global one;
  most-specific wins, concrete always beats wildcard, else it falls through to
  `onUnknown`. The unmatched tail arrives typed via `RouteParams.rest`, and the
  route round-trips so the 404 URL is preserved.
- **Route → URL** — `raku(...)` now returns a `RakuRouter` exposing
  `hrefOf(route)` / `uriOf(route)`, the tree's reverse direction, for share
  links, deep links, and `<a href>`s.
- **Browser tab titles** — `route(..., title: (route) => '…')` sets the tab /
  task-switcher label of the active leaf. Opt-in; the platform is untouched
  when no route declares a title.
- **`context.replaceSilently(route)`** — updates the address bar in place (no
  new history entry), wrapping `Router.neglect`. For transient, shareable URL
  state like a search query or filter.

## 0.1.0

First public release — a tiny, code-generation-free, UI-agnostic router for
Flutter.

Highlights:

- **Type-safe routes, no codegen** — routes are plain `sealed` classes; an
  exhaustive `switch` is your route table.
- **Declarative deep linking** — `raku(routes: […])` maps a URL's structure
  to a typed navigation stack, both ways, with no hand-written parsing.
- **Nested tabs built in** — each branch keeps its own persistent back stack and
  tabs nest arbitrarily.
- **Guards & redirects** — `RouteGuard` (predictive-back aware) and
  loop-protected `RouteRedirect`.
- **Built-in transitions** — `slideIn`, `none`, `fade`, `slide`, `riseUp`, all
  Material/Cupertino-free.
- **No dependencies beyond `flutter`** — no state-management or design-system
  coupling. Supports all 6 platforms; WASM-ready. SDK floor: Dart 3.6 /
  Flutter 3.27.
