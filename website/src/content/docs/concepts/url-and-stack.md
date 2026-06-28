---
title: URL ⇄ stack
description: A URL's structure reconstructs the whole navigation stack — and a typed route rebuilds its URL. Both ways, no hand-written parsing.
---

The core idea of raku_router's deep linking: **a URL's path structure maps to a
navigation stack** — and the mapping runs both ways.

## URL → stack

A deep link doesn't just open a screen; its *structure* rebuilds the whole
back history. `/feed/notes/42` becomes `[Feed, Note(42)]`, so **back returns to
Feed**, not a rootless screen.

<div class="rk-flow">
	<div class="box url">/feed/notes/42</div>
	<div class="arrow">→</div>
	<div class="box">Feed</div>
	<div class="arrow">→</div>
	<div class="box accent">Note(42)</div>
	<div class="note">the whole ancestor chain becomes the stack; back pops it</div>
</div>

You declare this once, as a tree of `route(...)` nodes — a child's path extends
its parent's:

```dart
raku(initial: const Home(), routes: [
  route('/feed', (_) => const Feed(), (_) => const FeedScreen(), children: [
    route('notes/:id', (p) => Note(p('id')), (n) => NoteScreen(id: n.id)),
  ]),
]);
```

The path's `:id` arrives **typed** through your constructor — never `params['id']`.

## stack → URL

The same tree builds a route's URL, so navigating by a typed object updates the
address bar automatically. `context.push(const Note('42'))` → the bar reads
`/feed/notes/42`.

<div class="rk-flow">
	<div class="box accent">Note(42)</div>
	<div class="arrow">→</div>
	<div class="box url">/feed/notes/42</div>
	<div class="note">one prop fills one :param automatically</div>
</div>

For URLs with **more than one `:param`** or a **`?query`**, give the node an
`encode:` — the inverse of `parse`:

```dart
route('/orgs/:org/members/:id',
    (p) => Member(p('org'), p('id')), (m) => MemberScreen(m),
    encode: (m) => RoutePath({'org': m.org, 'id': m.id}));
```

## Why this matters

Because the URL *is* the stack, three things come for free: real deep links
(shareable, restore back history), **browser back/forward** (the browser replays
your URL history — see [Tabs & preserved state](/raku_router/concepts/tabs-state/)), and
**state restoration** across process death.
