---
title: State restoration
description: Restore the navigation location across process death with one line.
---

Because `raku(...)` is a standard `RouterConfig`, the **navigation location
is restored across process death** for free — just give `MaterialApp.router` a
`restorationScopeId`:

```dart
MaterialApp.router(restorationScopeId: 'app', routerConfig: router);
```

Flutter saves the current `RouteInformation` and re-feeds it to a fresh delegate
on restart, which **reconstructs the stack from the URL** — so a user who is
killed deep in the app returns to the same screen (the active path; inactive tabs
restore to their initial route, as with a cold link). Verified end-to-end with
`restartAndRestore`, including a negative case without restoration.

## Per-screen widget state

To restore a *screen's* own widget state (a half-typed form, a scroll offset),
use Flutter's `RestorationMixin` in that screen and give its page a
`restorationId` via a custom `pageBuilder` — the hook is plumbed through
`RakuPage`. The router restores *which* screens are shown; each screen
restores its own contents.
