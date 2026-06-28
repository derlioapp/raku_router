---
title: Clean web URLs
description: Serve path URLs instead of the hash, and make deep links survive a refresh.
---

**Goal:** `/feed/notes/42` in the address bar instead of `/#/feed/notes/42`, with
deep links and refresh working.

## Use the path strategy

raku_router stays dependency-free, so the URL strategy is yours to pick. Call it once
in `main()` before `runApp`:

```dart
import 'package:flutter_web_plugins/url_strategy.dart';

void main() {
  usePathUrlStrategy(); // clean paths instead of the hash
  runApp(MaterialApp.router(routerConfig: router));
}
```

Omit it for the default hash strategy (works with no server config).

## SPA fallback (so refresh / deep links work)

With path URLs, the host must serve `index.html` for **any** unknown path —
otherwise refreshing `/feed/notes/42` 404s. The usual single-page-app rewrite:

- **Cloudflare Pages / Netlify:** add a catch-all rewrite of `/*` → `/index.html`.
- **Firebase Hosting:** set `"rewrites": [{ "source": "**", "destination": "/index.html" }]`.

## What you get

Browser back/forward replays your URL history and raku_router reconciles the tree in
place — you land on the right screen with the other tabs' state intact. See
[Tabs & preserved state](/raku_router/concepts/tabs-state/).
