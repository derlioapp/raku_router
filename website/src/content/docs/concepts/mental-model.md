---
title: The mental model
description: raku_router is five small layers you compose — from a route as plain data up to a declarative URL tree.
---

raku_router is **five small layers**. Each one is independently useful, and each is
built on the one above it. You can stop at any level your app needs.

<div class="rk-flow">
	<div class="stack">
		<div class="box accent">RakuRoute</div>
		<div class="box">RouteStack</div>
		<div class="box">RouteStackView</div>
		<div class="box">BranchedRouteStack</div>
		<div class="box">raku(routes: […])</div>
	</div>
	<div class="note">data → reactive stack → a Navigator → tabs → a URL tree</div>
</div>

## 1. `RakuRoute` — a route is data

A destination is an immutable object, ideally a `sealed` class so a `switch` over
it is exhaustive (the compiler is your route table). No code generation.

```dart
sealed class AppRoute extends RakuRoute { const AppRoute(); }
class Home extends AppRoute { const Home(); }
class Note extends AppRoute {
  const Note(this.id);
  final String id;
  @override
  List<Object?> get props => [id]; // identity + URL building
}
```

## 2. `RouteStack` — a reactive list of routes

The heart of raku_router: a mutable `List<route>` exposed as a `ValueListenable`. It
depends only on `flutter/foundation` — no UI, no state-management. `push`, `pop`,
`replace`, `reset`. Mutations honour guards and redirects.

## 3. `RouteStackView` — render a stack as a `Navigator`

Turns a `RouteStack` into a real `Navigator` with pages and transitions. Drop it
into `MaterialApp.home` (or any app shell). This is all you need for an app
without deep linking.

## 4. `BranchedRouteStack` — many stacks, one active

Tabs. Each branch owns its own `RouteStack`, so switching tabs preserves each
one's back history. `BranchedStackView` renders it (lazy, state-preserving).

## 5. `raku(routes: […])` — a declarative URL tree

The top layer ties a **URL's structure** to a typed navigation stack, both ways:
deep linking, browser back/forward, and address-bar sync, with no hand-written
parsing. See **[URL ⇄ stack](/raku_router/concepts/url-and-stack/)**.

:::tip
Most apps only ever touch layer 5 (`raku_router`) and the route classes. The lower
layers are there when you want to drop down — e.g. a `RouteStack` inside a
modal, with no URL involved.
:::
