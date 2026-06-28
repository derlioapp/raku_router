---
title: Why raku_router
description: Where raku_router fits, and how it compares to go_router and auto_route.
---

The design goals come from one observation: every router pushes navigation
complexity *somewhere* — `go_router` into redirects/shells, `auto_route` into a
build step, Navigator 2.0 onto you. raku_router's bet is that for most apps the real
need is modest, and a small reactive core beats a big framework.

## Principles

- **Type-safe, no codegen.** Routes are plain `sealed` classes; an exhaustive
  `switch` is your route table. Type-safety comes from Dart, not a build step.
- **Nested navigation built in.** Each tab/branch gets its own persistent back
  stack — the thing `StatefulShellRoute` does, but by default.
- **Deep linking is declarative.** One route tree maps a URL's *structure* to a
  typed navigation stack, both ways.
- **No state or design-system dependency.** The core only needs `flutter`; you
  inject the pages and transitions.

## Why not just use go_router / auto_route?

Use them if you want the ecosystem and don't mind their trade-offs. Reach for
raku_router when you want navigation that is *yours*: a couple hundred lines you can
read in one sitting, no code generation, and no dependency creep into your state
or UI layers.

## What it intentionally does *not* do

- **The URL encodes the active path, not every tab's divergent history.** A cold
  deep link starts the other tabs at their initial route — a single URL can't
  carry every branch's history (no router can). Within a session, inactive tabs
  and unchanged screens keep their state across in-app navigation *and* browser
  back/forward.
- **No animation library** — bring your own `RouteTransitionsBuilder` for fancy
  ones (a small, framework-free set ships in the box).

These are deliberate omissions for a small core, not oversights.
