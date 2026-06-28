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
typed-navigation thesis. For richer needs (the raw `Route` objects), pass a
`NavigatorObserver` to `RouteStackView.observers`.
