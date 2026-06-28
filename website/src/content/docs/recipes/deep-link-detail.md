---
title: Deep link to a detail screen
description: Open a detail screen from a URL with the right back history — inside a tab, or full-page over the shell.
---

**Goal:** `/feed/notes/42` opens the note with **back returning to the feed**, and
a shared `/photo/9` opens full-page over the tab bar.

## Inside a tab (back stays in the tab)

Nest the detail under its parent — its URL extends the parent's, so the ancestor
chain becomes the stack.

```dart
route('/feed', (_) => const Feed(), (_) => const FeedScreen(), children: [
  route('notes/:id', (p) => Note(p('id')), (n) => NoteScreen(id: n.id)),
]);
```

`/feed/notes/42` → `[Feed, Note(42)]`. Back pops to `Feed`, within the feed tab.

## Full-page over the shell

A top-level `route(...)` — a sibling of the `tabs(...)` node — sits in a root
navigator **above** the tab bar.

```dart
raku(routes: [
  tabs(/* feed, settings */),
  route('/photo/:id', (p) => Photo(p('id')), (n) => PhotoScreen(id: n.id)),
]);
```

`context.push(const Photo('9'))` covers the bar; back returns to the preserved
shell. `context.push` is **level-routed** automatically — you don't choose.

**Notes**

- Typed params arrive through your constructor: `(p) => Note(p('id'))`, plus
  `p.asInt('id')` and `p.query('q')`.
- Need a multi-`:param` or `?query` URL to round-trip? Add an
  [`encode:`](/raku_router/concepts/url-and-stack/).
