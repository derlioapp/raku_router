---
title: Web
description: The browser drives raku_router for free; pick your URL strategy and keep state across back/forward.
---

`raku(...)` is a standard Navigator 2.0 `RouterConfig`, so the browser's
address bar and **back/forward buttons drive it for free** — each typed
navigation updates the URL, and a back/forward delivers the previous URL, which
the router reconciles **in place**: you land on the right screen with the other
tabs' history and unchanged screens' state intact (not a rebuilt-from-scratch
tree).

## URL strategy

raku_router stays dependency-free, so the URL strategy is yours to pick — call it
once in `main()` before `runApp`:

```dart
import 'package:flutter_web_plugins/url_strategy.dart';

void main() {
  usePathUrlStrategy(); // clean paths (/feed/notes/42) instead of the hash (/#/…)
  runApp(const MyApp());
}
```

Omit it for the default hash strategy. Either way the same route tree resolves.

:::tip[SPA fallback]
For clean paths, your host must serve `index.html` for unknown routes — the usual
single-page-app deploy step (e.g. a catch-all rewrite on Cloudflare Pages,
Netlify, or Firebase Hosting).
:::

## What's preserved on back/forward

A cold deep link starts inactive tabs at their initial route (a URL can only
encode the active path). But **within a session**, browser back/forward preserves
inactive tabs' history and the element state of unchanged screens — verified by a
back/forward sequence test.
