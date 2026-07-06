---
title: Route tree & deep linking
description: Declare each screen's URL once; a URL's structure rebuilds the navigation stack, both ways.
---

Declare each screen's URL **once** in a tree of `route(...)` (and `tabs(...)`)
nodes. A URL's *structure* rebuilds the navigation stack: a deep link to
`/feed/notes/42` produces `[Feed, Note(42)]`, so **back returns to Feed** — with
no hand-written `pathSegments` parsing, no manual URL building, and no code
generation. The path's `:params` arrive typed via your constructor.

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
bar updates itself; a link to `/notes/42` opens `NoteScreen('42')`.

## Typed params

`parse` receives a `RouteParams`: `p('id')` for a path param, `p.asInt('id')`,
`p.optionalInt('id')`, and `p.query('q')` for the URL's `?query`.

## Building URLs back: `encode:`

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

## Not found (catch-all `*`)

A trailing `*` in a path makes a **catch-all**: a typed 404 for any URL a
concrete route doesn't claim. Nest it under a section for a **subtree-scoped**
not-found (it shows inside that tab, stacked on the section root, so *back*
returns there); put it at the **top level** for a **global** one.

```dart
raku(
  initial: const Feed(),
  routes: [
    tabs(shell: ..., branches: [
      [route('/feed', (_) => const Feed(), (_) => const FeedScreen(), children: [
        route('notes/:id', (p) => Note(p('id')), (n) => NoteScreen(id: n.id)),
        // /feed/anything-else → the feed section's own 404, inside the tab.
        route('*', (p) => FeedMissing(p.rest), (n) => MissingScreen(n.path)),
      ])],
      [route('/settings', (_) => const Settings(), (_) => const SettingsScreen())],
    ]),
    // Anything no section claims (e.g. /nope, /settings/x) → the global 404.
    route('*', (p) => NotFound(p.rest), (n) => NotFoundScreen(n.path)),
  ],
);
```

The rules fall out of ordinary matching:

- a **concrete** route always beats a wildcard;
- the **most specific** catch-all wins (`/feed/*` over a top-level `/*`);
- if a section defines none, the URL falls through to the nearest catch-all above
  it.

The unmatched tail arrives typed via `p.rest` (e.g. `garbage/x`), and a catch-all
route **round-trips** like any other — so the 404's URL is preserved and
shareable, not rewritten.

## Unknown URLs (`onUnknown:`)

`onUnknown:` is the escape hatch for when a URL matches **no** route (and no
catch-all) — map it to a fallback route outside the tree. A top-level `route('*',
…)` is usually the better choice, because it stays a normal, addressable route;
reach for `onUnknown:` when you'd rather handle the miss imperatively.
