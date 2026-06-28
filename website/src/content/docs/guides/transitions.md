---
title: Transitions
description: A premium default slide, plus a small framework-free set you can override globally or per route.
---

`raku(...)` defaults to the premium `RakuTransitions.slideIn` — a
direction-parametric page slide synthesised from platform best practice:
Material 3 emphasized easing on the incoming page, an iOS-style parallax recede on
the outgoing one, and a subtle dim scrim.

```dart
// Global override:
raku(transition: RakuTransitions.none, /* ... */);

// Per node:
route('/sheet', (_) => const Sheet(), (_) => const SheetScreen(),
    transition: RakuTransitions.slideIn(from: SlideFrom.bottom));
```

The lower-level `RouteStackView` / `BranchedStackView` default to a neutral
`RakuTransitions.fade`.

## What ships

All are Material/Cupertino-free:

- `none` — no animation.
- `fade` — cross-fade.
- `slide` — horizontal slide-in (iOS-like, framework-free).
- `riseUp` — a short rise-up reveal; only one page paints during the transition,
  avoiding the "two pages briefly overlap" flash.
- `slideIn({from, parallax, fade, dim})` — the premium, parametric default.

Bring your own `RouteTransitionsBuilder` for anything else — and a route's own
`RouteTransition` mixin overrides everything for that screen.
