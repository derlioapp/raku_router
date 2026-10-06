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

## From a push notification (no `BuildContext`)

A notification carries a URL or path. Resolve it with the router you got from
`raku(...)` — `routeOf` returns `null` for anything your tree doesn't know, and
never throws on garbage — then `go` there so the back stack is rebuilt like a
deep link:

```dart
onNotificationTap((String payload) {
  final route = router.routeOf(Uri.tryParse(payload) ?? Uri());
  if (route != null) router.go(route); // /feed/notes/42 → [Feed, Note(42)]
});
```

Use `router.push(route)` instead to open it on top of where the user already is.

**Notes**

- Typed params arrive through your constructor: `(p) => Note(p('id'))`, plus
  `p.asInt('id')` and `p.query('q')`. If `parse` throws on a bad value
  (`/feed/notes/abc` with `asInt`), the route simply doesn't match — the link
  falls through to your 404 / `onUnknown` instead of crashing.
- Need a multi-`:param` or `?query` URL to round-trip? Add an
  [`encode:`](/raku_router/concepts/url-and-stack/).
