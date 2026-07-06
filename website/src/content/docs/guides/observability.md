---
title: Observability
description: Observe navigation in terms of your typed routes — for analytics and logging.
---

Pass `onNavigation:` to observe navigation in terms of your **typed routes**, not
a raw `Route<dynamic>`. It reports the active leaf route after every change that
moves it — a push, pop, tab switch, or browser back/forward — once per change, and
not for the initial route (you already have `initial`).

```dart
raku(
  initial: const Home(),
  routes: [...],
  onNavigation: (route) => analytics.screen(route.name),
);
```

This is deliberately minimal — one callback, consistent with raku_router's
typed-navigation thesis. It already covers **every** navigator (the root and each
tab branch), so for plain route-name analytics you rarely need anything else.

## Raw `NavigatorObserver`s

Some packages want the raw `Route` lifecycle rather than a route name —
`FirebaseAnalyticsObserver`, `SentryNavigatorObserver`, or a `RouteObserver` that
drives `RouteAware` widgets. Pass `observers:`:

```dart
raku(
  initial: const Home(),
  routes: [...],
  observers: () => [FirebaseAnalyticsObserver(analytics: analytics)],
);
```

It's a **factory** (`() => [...]`), not a plain list — and that matters. A single
`NavigatorObserver` instance can attach to only one `Navigator`, but a raku app
has several: the root, plus one per tab branch. The factory is called **once per
navigator**, so each gets its own fresh instances. The upshot is that an observer
sees **in-tab** pushes too, not only top-level ones — exactly what analytics and
crash-reporting want.

:::note
At the low level (no deep linking) `RouteStackView.observers` takes a plain
`List<NavigatorObserver>` for that single navigator; the factory exists because
`raku(...)` fans out across many.
:::
