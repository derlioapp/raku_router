---
title: Not-found (404) pages
description: A typed catch-all route for unmatched URLs — global, or scoped to one section.
---

**Goal:** show a 404 screen for any URL a concrete route doesn't claim — and,
ideally, a *different* one per section (an unknown `/feed/…` stays in the Feed
tab; an unknown `/settings/…` stays in Settings).

A trailing `*` in a `route(...)` path is a **catch-all**. It's a normal typed
route — it renders a screen, and its URL round-trips — so there's no special
"error builder" to learn.

## A global 404

Put a `route('*', …)` at the top level. It matches anything no other route does:

```dart
class NotFound extends AppRoute {
  const NotFound(this.path);
  final String path;
  @override
  List<Object?> get props => [path];
}

raku(
  initial: const Home(),
  routes: [
    route('/', (_) => const Home(), (_) => const HomeScreen()),
    route('*', (p) => NotFound(p.rest), (n) => NotFoundScreen(attempted: n.path)),
  ],
);
```

`p.rest` is the unmatched tail (e.g. `deep/unknown/path`), typed and ready to show
or log. Because the route round-trips, the address bar keeps the URL the user
actually hit — handy for "we couldn't find `/x`" copy and for sharing.

## A section-scoped 404

Nest the catch-all under a section and it scopes there — it renders **inside that
tab**, stacked on the section root, so *back* returns to the section rather than
leaving it:

```dart
raku(
  initial: const Feed(),
  routes: [
    tabs(shell: ..., branches: [
      [route('/feed', (_) => const Feed(), (_) => const FeedScreen(), children: [
        route('notes/:id', (p) => Note(p('id')), (n) => NoteScreen(id: n.id)),
        route('*', (p) => FeedMissing(p.rest), (n) => FeedMissingScreen(n.path)),
      ])],
      [route('/settings', (_) => const Settings(), (_) => const SettingsScreen())],
    ]),
    // Sections without their own catch-all fall through to this one.
    route('*', (p) => NotFound(p.rest), (n) => NotFoundScreen(attempted: n.path)),
  ],
);
```

**How ties resolve**

- A **concrete** route always beats a catch-all — `/feed/notes/42` opens the note,
  never the 404.
- The **most specific** catch-all wins — `/feed/xyz` hits `FeedMissing`, not the
  global `NotFound`.
- A section with **no** catch-all falls through to the nearest one above it — an
  unknown `/settings/…` here lands on the global `NotFound` (full-page above the
  shell).

**`onUnknown:` vs a catch-all**

`raku(onUnknown:)` also maps unmatched URLs to a fallback, but a top-level
`route('*', …)` is usually better: it's a real, addressable, round-tripping route.
Reach for `onUnknown:` only when you'd rather handle the miss imperatively,
outside the tree.
