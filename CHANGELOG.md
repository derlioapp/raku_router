## 0.3.0

Hardening and the API freeze review on the way to `1.0`. Contains **breaking
changes** — see *Breaking* below for the migration notes.

**Fixes**

- **A malformed deep link no longer crashes the app.** A `parse` that throws on
  bad input (`p.asInt('id')` on `/notes/abc`, `Enum.values.byName`) or a URL
  with invalid percent-encoding is now a *non-match*: the URL falls through to
  a catch-all route or `onUnknown`. URLs are untrusted input.
- **A redirect now protects its whole subtree.** A deep link (or `go`) checks
  the redirect of every route on the rebuilt path, not just the leaf's — so a
  sign-in redirect on `/admin` also covers `/admin/users/1`.
- **Browser back/forward honours `RouteGuard`.** On the web, a URL change that
  would remove a guarded page is vetoed (`onPopBlocked` runs, the address bar is
  put back); previously it slipped through.
- **System back closes an open dialog / bottom sheet first.** It used to pop the
  page underneath along with it. Works for overlays on the root navigator, on a
  tab's navigator, and with a plain `RouteStackView`.
- `onPopBlocked` now gets a `context` inside the guarded page's own stack, so a
  confirming `context.pop()` pops the right page inside a tab.
- A slow async redirect can no longer overwrite a newer navigation.
- Declaring the same route type in two `route(...)`s now asserts (it used to be
  silently overwritten).

**New**

- **`RakuRouter.go` / `push` / `current` / `routeOf`** — navigate without a
  `BuildContext` (push notifications, auth listeners): `go` rebuilds the
  location like a deep link, `push` lands at the right level, `current` is a
  `ValueListenable<RakuRoute>` of the active leaf, `routeOf` maps a URL to a
  typed route (or `null`) and never throws.
- **`context.go(route)`** — the in-widget form of `go`.
- **`raku(title:)`** — fallback tab title for routes without a `title:`, so the
  label no longer goes stale when leaving a titled route.
- URL matching rules are now defined and tested: case-sensitive, trailing and
  doubled slashes ignored, `#fragment` ignored, last value wins for a repeated
  query key.

**Breaking**

- **One default transition everywhere:** `RouteStackView`, `BranchedStackView`
  and `RakuPage` now default to `RakuTransitions.slideIn` (was `fade`), like
  `raku(...)`. Their `transitionsBuilder` is nullable (null = the default). Pass
  `transitionsBuilder: RakuTransitions.fade` for the old look.
- **Smaller public surface.** No longer exported: `RouteTree`, `RouteMatch`,
  `ScreenMatch`, `TabsMatch`, `RakuNavigator`; `RouteStack.reconcileRoutes`,
  `handlePageRemoved` and `resolve` are internal. `ScreenNode` / `TabsNode` can
  only be built with `route(...)` / `tabs(...)`.
- `RakuRoute.sameDestination` is removed — use `==`.
- `RakuRouter`, `RouteParams`, `RoutePath`, `RakuEntry`, `RouteBranch`,
  `ScreenNode` and `TabsNode` are now `final` classes.

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
