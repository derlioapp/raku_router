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

## Unknown URLs

Pass `onUnknown:` to map an unmatched URL to a fallback route (e.g. a 404
screen).
