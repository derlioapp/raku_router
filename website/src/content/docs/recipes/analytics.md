---
title: Screen-view analytics
description: Log a screen view on every navigation, in terms of your typed routes.
---

**Goal:** send a screen-view event whenever the active screen changes — without
digging through raw `Route<dynamic>` objects.

Pass `onNavigation:` to `raku_router`. It reports the active leaf as a typed
`RakuRoute` after every change that moves it (push, pop, tab switch, browser
back/forward), once per change, and not for the initial route.

```dart
raku(
  initial: const Feed(),
  routes: [...],
  onNavigation: (route) {
    analytics.logScreenView(screenName: route.name);

    // Or switch on the typed route for richer events:
    switch (route) {
      case Note(:final id):
        analytics.log('note_opened', {'id': id});
      case _:
        break;
    }
  },
);
```

**Notes**

- `route.name` defaults to the type name (`Note`, `Feed`); override `name` on the
  route for a custom label.
- The initial route isn't reported (you already have `initial` — log it once at
  startup if you need it).
- Need the raw framework `Route` objects (durations, modal barriers) or a
  drop-in like `FirebaseAnalyticsObserver`? Pass `observers:` to `raku(...)` — a
  factory that attaches fresh `NavigatorObserver`s to the root and each tab
  branch. See [Observability](/raku_router/guides/observability/).
