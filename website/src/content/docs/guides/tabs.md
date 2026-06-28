---
title: Tabs & nested navigation
description: Each tab keeps its own persistent back stack; full-page routes sit above the shell.
---

Each branch of a tabbed shell owns an independent stack, so switching tabs
preserves each one's back history — the "persistent tab stack" behaviour of
`StatefulShellRoute`, built in.

## In the route tree

**Tabs** are a node: `tabs(shell:, branches:)`. A route inside a branch navigates
**within its tab** (the shell stays put, only the content animates); a
`route(...)` at the top level (a sibling of the `tabs(...)` node) is **full-page**
above the shell. `context.push(route)` lands at the right level automatically, and
tabs **nest arbitrarily**.

```dart
final router = raku(
  initial: const Feed(),
  routes: [
    tabs(
      shell: (context, tabs, child) => Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: tabs.index,
          onDestinationSelected: tabs.go,
          destinations: const [/* ... */],
        ),
      ),
      branches: [
        [route('/feed', (_) => const Feed(), (_) => const FeedScreen())],
        [route('/settings', (_) => const Settings(), (_) => const SettingsScreen())],
      ],
    ),
    // Full-page above the shell:
    route('/photo/:id', (p) => Photo(p('id')), (n) => PhotoScreen(id: n.id)),
  ],
);
```

Branches build **lazily** (a tab's `Navigator` is created the first time it is
shown) and are then cached and kept alive, so state and scroll positions survive
tab switches. Each branch gets its own `HeroController`.

## Without deep linking

The same model is available at the low level via `BranchedRouteStack` +
`BranchedStackView`:

```dart
final tabs = BranchedRouteStack(branches: [
  RouteBranch(id: 'feed',     initial: const FeedTab()),
  RouteBranch(id: 'settings', initial: const SettingsTab()),
]);

Scaffold(
  body: BranchedStackView(controller: tabs, builder: buildScreen),
  bottomNavigationBar: ListenableBuilder(
    listenable: tabs,
    builder: (_, __) => NavigationBar(
      selectedIndex: tabs.index,
      onDestinationSelected: tabs.go,
      destinations: const [/* ... */],
    ),
  ),
);
```
