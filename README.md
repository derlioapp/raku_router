# raku_router

A tiny, **code-generation-free**, UI-agnostic router for Flutter.

**[📖 Documentation](https://derlioapp.github.io/raku_router/) · [▶ Live demo](https://derlioapp.github.io/raku_router/live-demo/)**

The design goals come from one observation: every router pushes navigation
complexity *somewhere* — `go_router` into redirects/shells, `auto_route` into a
build step, Navigator 2.0 onto you. Raku's bet is that for most apps the
real need is modest, and a small reactive core beats a big framework.

- **Type-safe, no codegen.** Routes are plain `sealed` classes. An exhaustive
  `switch` is your route table. No `build_runner`, no `.gr.dart`, no annotations.
- **Nested navigation built in.** Each tab/branch gets its own persistent back
  stack — the thing `StatefulShellRoute` does, but by default.
- **Deep linking is opt-in and toggleable.** One call turns it on; omit it and
  the URL/Router machinery is never built. Default: off.
- **No state-management or design-system dependency.** The core only needs
  `flutter`. You inject the pages/transitions, so it drops into Material,
  Cupertino, or a custom design system equally.

> Pre-`1.0`: the **public API surface is reviewed and locked** (naming, route
> equality, navigation results, the error/assertion contract); further changes
> are additive features, not churn. See the [CHANGELOG](CHANGELOG.md).

## Mental model

```
RakuRoute        // your route = immutable data (sealed class)
   │
RouteStack           // a reactive List<route> (ValueListenable) — push/pop/replace
   │
RouteStackView       // renders a stack as a Navigator (+ optional system-back)
   │
BranchedRouteStack   // many stacks (tabs), one active — nested navigation
   │
raku(routes: […]) // a declarative route tree: a URL's structure ⇄ the stack
```

## Quick start (no deep linking)

```dart
sealed class AppRoute extends RakuRoute {
  const AppRoute();
}
class Home extends AppRoute { const Home(); }
class NoteDetail extends AppRoute {
  const NoteDetail(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

final stack = RouteStack(const Home());

MaterialApp(
  home: RouteStackView(
    stack: stack,
    builder: (context, route) => switch (route as AppRoute) {
      Home()                => const HomeScreen(),
      NoteDetail(:final id) => NoteScreen(id: id),
    },
  ),
);
```

Navigate from anywhere below the view — no constructors to thread:

```dart
final stack = RouteStackScope.of(context);
stack.push(const NoteDetail('42'));
stack.pop();
```

## Nested tabs (persistent back stacks)

```dart
final tabs = BranchedRouteStack(branches: [
  RouteBranch(id: 'feed',     initial: const FeedTab()),
  RouteBranch(id: 'settings', initial: const SettingsTab()),
]);

Scaffold(
  body: BranchedStackView(controller: tabs, builder: buildScreen),
  bottomNavigationBar: ListenableBuilder(
    listenable: tabs,
    builder: (_, __) => BottomNavigationBar(
      currentIndex: tabs.index,
      onTap: (i) => tabs.index = i,
      items: const [...],
    ),
  ),
);
```

Switching tabs preserves each tab's stack. Each branch handles the system back
gesture for its own stack.

## Guards & redirects

```dart
class Editor extends AppRoute with RouteGuard {
  const Editor();
  @override
  bool get canPop => !hasUnsavedChanges; // false blocks the pop (read synchronously)
}

class LegacyNote extends AppRoute with RouteRedirect {
  const LegacyNote(this.id);
  final String id;
  @override
  RakuRoute redirect() => NoteDetail(id); // resolved before it's shown
}
```

Redirect chains are followed and **loop-protected** by the package — you don't
have to hand-write the "am I already going there?" check.

## Deep linking — one declarative route tree

Declare each screen's URL **once** in a tree of `route(...)` (and `tabs(...)`)
nodes. A URL's *structure* rebuilds the navigation stack: a deep link to
`/feed/notes/42` produces `[Feed, Note(42)]`, so **back returns to Feed** — the
web-grade behaviour, with no hand-written `pathSegments` parsing, no manual URL
building, and no code generation. The path's `:params` arrive typed via your
constructor — never `params['id']`.

```dart
final router = raku(
  initial: const Home(),
  routes: [
    route('/', (_) => const Home(), (_) => const HomeScreen(), children: [
      // /notes/:id — nested, so it stacks on top of Home.
      route('notes/:id', (p) => Note(p('id')), (n) => NoteScreen(id: n.id)),
    ]),
  ],
);

MaterialApp.router(routerConfig: router);
```

Navigate with typed objects — `context.push(const Note('42'))` — and the address
bar updates itself; a link to `/notes/42` opens `NoteScreen('42')`. Pages animate
with the premium `RakuTransitions.slideIn` by default (override with
`transition:`, or `RakuTransitions.none` to disable).

A single-prop path round-trips automatically. For a URL with **more than one
`:param`**, or one that carries **`?query`** state, give the node an `encode:` —
the inverse of `parse`, so route → URL stays exact:

```dart
route('/orgs/:org/members/:id',
    (p) => Member(p('org'), p('id')), (m) => MemberScreen(m),
    encode: (m) => RoutePath({'org': m.org, 'id': m.id}));

route('/search', (p) => Search(p.query('q') ?? ''), (s) => SearchScreen(s),
    encode: (s) => RoutePath(const {}, query: {'q': s.term}));
```

For analytics or logging, pass `onNavigation:` — it reports the active route as a
typed object (not a raw `Route<dynamic>`) on every change, including browser
back/forward:

```dart
raku(initial: const Home(), routes: [...],
    onNavigation: (route) => analytics.screen(route.name));
```

**Tabs** are a node: `tabs(shell: ..., branches: [...])`. A route inside a branch
navigates **within its tab** (the shell stays put, only the content animates); a
`route(...)` at the top level (a sibling of the `tabs(...)` node) is **full-page**
above the shell. `context.push(route)` lands at the right level automatically, and
tabs nest arbitrarily. See `example/`.

```dart
final router = raku(
  initial: const Feed(),
  routes: [
    tabs(
      shell: (context, tabs, child) => Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: tabs.index,
          onDestinationSelected: tabs.go,
          destinations: const [/* ... */],
        ),
      ),
      branches: [
        [route('/feed', (_) => const Feed(), (_) => const FeedScreen())],
        [route('/settings', (_) => const Settings(), (_) => const SettingsScreen())],
      ],
    ),
    route('/photo/:id', (p) => Photo(p('id')), (n) => PhotoScreen(id: n.id)),
  ],
);
```

## Transitions

`raku_router` defaults to the premium `RakuTransitions.slideIn` (set
`transition:` to change it globally, `RakuTransitions.none` to disable, or
`route(..., transition: ...)` per node). The lower-level `RouteStackView` /
`BranchedStackView` default to a neutral `RakuTransitions.fade`.

```dart
route('/sheet', (_) => const Sheet(), (_) => const SheetScreen(),
    transition: RakuTransitions.slideIn(from: SlideFrom.bottom));
```

`RakuTransitions` ships `none`, `fade`, `slide`, `riseUp`, and the
parametric `slideIn` — all Material/Cupertino-free.

## Web

`raku(...)` is a standard Navigator 2.0 `RouterConfig`, so the browser's
address bar and **back/forward buttons drive it for free** — each typed
navigation updates the URL, and a back/forward delivers the previous URL, which
the router reconciles **in place**: you land on the right screen with the other
tabs' history and unchanged screens' state intact (not a rebuilt-from-scratch
tree).

raku_router stays dependency-free, so the **URL strategy is yours to pick** — call
it once in `main()` before `runApp`:

```dart
import 'package:flutter_web_plugins/url_strategy.dart';

void main() {
  usePathUrlStrategy(); // clean paths (/feed/notes/42) instead of the hash (/#/…)
  runApp(const MyApp());
}
```

Omit it for the default hash strategy. Either way the same route tree resolves;
for clean paths your host must serve `index.html` for unknown routes (SPA
fallback), the usual single-page-app deploy step.

## State restoration

Because `raku(...)` is a standard `RouterConfig`, the **navigation location
is restored across process death** for free — just give `MaterialApp.router` a
`restorationScopeId`:

```dart
MaterialApp.router(restorationScopeId: 'app', routerConfig: router);
```

Flutter saves the current `RouteInformation` and re-feeds it to a fresh delegate
on restart, which **reconstructs the stack from the URL** — so a user who is
killed deep in the app returns to the same screen (the active path; inactive tabs
restore to their initial route, as with a cold link). Verified end-to-end with
`restartAndRestore`.

For a *screen* to restore its own widget state (a half-typed form, scroll
offset), use Flutter's `RestorationMixin` in that screen and give its page a
`restorationId` via a custom `pageBuilder` — the hook is plumbed through
`RakuPage`.

## What it intentionally does *not* do

- **The URL encodes the active path, not every tab's divergent history.** A URL's
  structure rebuilds the active stack and resolves the right tab; a *cold* deep
  link starts the other tabs at their initial route — a single URL can't carry
  every branch's history (no router can). **Within a session, though, inactive
  tabs and the element state of unchanged screens are preserved** across both
  in-app navigation *and* browser back/forward: the router reconciles the live
  tree in place rather than rebuilding it.
- No animation library; bring your own `RouteTransitionsBuilder` for fancy ones.

These are deliberate omissions for a small core, not oversights.

## Why not just use go_router / auto_route?

Use them if you want the ecosystem and don't mind their trade-offs. Reach for
Raku when you want navigation that is *yours*: a couple hundred lines you can
read in one sitting, no code generation, and no dependency creep into your state
or UI layers.
