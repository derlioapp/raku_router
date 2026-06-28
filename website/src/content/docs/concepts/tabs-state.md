---
title: Tabs & preserved state
description: Each tab keeps its own back stack, and state survives both in-app navigation and browser back/forward.
---

A tabbed shell is a `tabs(...)` node with one branch per tab. Each branch owns an
**independent `RouteStack`**, so the tabs are parallel, not a single stack.

<div class="rk-flow">
	<div class="stack">
		<div class="box accent">Feed tab</div>
		<div class="box">Feed → Note(2) → Note(3)</div>
	</div>
	<div class="stack">
		<div class="box">Settings tab</div>
		<div class="box">Settings → Profile</div>
	</div>
	<div class="note">switching tabs preserves each stack — you return exactly where you were</div>
</div>

Branches are rendered in an `IndexedStack`, built **lazily** (a tab's `Navigator`
is created the first time it's shown) and then **kept alive** — so scroll
positions and form state survive tab switches. Each tab gets its own
`HeroController`.

## State across a URL change

Here's the subtle part. When a **platform URL change** arrives — a browser
back/forward, or a deep link — raku_router does **not** rebuild the tree from
scratch. It **reconciles in place**:

<div class="rk-flow">
	<div class="box url">browser back → /feed/notes/2</div>
	<div class="arrow">→</div>
	<div class="box accent">active tab follows the URL</div>
	<div class="arrow">+</div>
	<div class="box">other tabs untouched</div>
	<div class="note">unchanged screens keep their element state; inactive tabs keep their history</div>
</div>

So on the web, the browser's back/forward replays your URL history (you land on
the right screen, in order) **and** the rest of the app keeps its state — not a
rebuilt-from-scratch tree.

## The one limit

A single URL can only encode the **active** path. So a *cold* deep link (opening
a URL fresh) starts the other tabs at their initial route — no router can carry
every branch's divergent history in one URL. Within a session, everything is
preserved.
