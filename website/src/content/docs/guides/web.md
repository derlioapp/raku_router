---
title: Web
description: The browser drives raku_router for free; pick your URL strategy and keep state across back/forward.
---

`raku(...)` is a standard Navigator 2.0 `RouterConfig`, so the browser's
address bar and **back/forward buttons drive it for free** — each typed
navigation updates the URL, and a back/forward delivers the previous URL, which
the router reconciles **in place**: you land on the right screen with the other
tabs' history and unchanged screens' state intact (not a rebuilt-from-scratch
tree).

## URL strategy

raku_router stays dependency-free, so the URL strategy is yours to pick — call it
once in `main()` before `runApp`:

```dart
import 'package:flutter_web_plugins/url_strategy.dart';

void main() {
  usePathUrlStrategy(); // clean paths (/feed/notes/42) instead of the hash (/#/…)
  runApp(const MyApp());
}
```

Omit it for the default hash strategy. Either way the same route tree resolves.

:::tip[SPA fallback]
For clean paths, your host must serve `index.html` for unknown routes — the usual
single-page-app deploy step (e.g. a catch-all rewrite on Cloudflare Pages,
Netlify, or Firebase Hosting).
:::

## What's preserved on back/forward

A cold deep link starts inactive tabs at their initial route (a URL can only
encode the active path). But **within a session**, browser back/forward preserves
inactive tabs' history and the element state of unchanged screens — verified by a
back/forward sequence test.

## Route → URL (links & sharing)

`raku(...)` returns a `RakuRouter` — a `RouterConfig` that also exposes the tree's
*reverse* direction. Turn a typed route into its URL for a share link, a deep
link, or an `<a href>`:

```dart
final router = raku(initial: const Home(), routes: [...]);

router.hrefOf(const Note('42'));      // '/feed/notes/42'
router.uriOf(const Search('shoes'));  // Uri: /search?q=shoes
```

It's built by the same tree that parses URLs, so route → URL and URL → route can
never drift — there's no second, hand-written "path builder" to keep in sync. The
value is the app-internal location; under the default hash strategy a real
anchor's `href` is that value after a `#`.

## Browser tab titles

Give a node a `title:` to set the browser tab (and Android task-switcher) label
while that route is the active leaf. Derive it from the route so detail pages read
well:

```dart
route('notes/:id', (p) => Note(p('id')), (n) => NoteScreen(id: n.id),
    title: (n) => 'Note ${n.id}');
```

It's opt-in and per-route: a route with no `title:` leaves the label untouched,
and if you declare none the platform is never called. Under the hood it uses the
same `SystemChrome.setApplicationSwitcherDescription` call as Flutter's `Title`
widget — and because raku sets it deeper in the tree, it wins over
`MaterialApp.title`.

## Transient URL state (no history spam)

`context.replaceSilently(route)` updates the address bar **in place** — no new
browser history entry, so back/forward skips it. Use it for URL state that should
be shareable and restorable but shouldn't clutter history: a search query, an
active filter, a within-page selection.

```dart
onChanged: (q) => context.replaceSilently(Search(q)),
// one history entry, not one per keystroke
```

It wraps Flutter's `Router.neglect` (which works because raku's delegate reports
`currentConfiguration`). Outside a deep-linked app — no `Router`, no URL — it
degrades to a plain `replace`.
