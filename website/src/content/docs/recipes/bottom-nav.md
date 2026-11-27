---
title: Bottom-nav app
description: A tabbed app where each tab keeps its own back stack.
---

**Goal:** a `NavigationBar` with tabs that each keep their own history, and a URL
per tab.

```dart
final router = raku(
  initial: const Feed(),
  routes: [
    tabs(
      shell: (context, tabs, child) => Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: tabs.index,
          onDestinationSelected: tabs.go, // tear-off: switches the active tab
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: 'Feed'),
            NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
      ),
      branches: [
        [route('/feed', (_) => const Feed(), (_) => const FeedScreen())],
        [route('/settings', (_) => const Settings(), (_) => const SettingsScreen())],
      ],
    ),
  ],
);
```

**Notes**

- Pushing a route from inside a tab (`context.push`) stays in that tab; the bar
  stays put.
- Switching tabs preserves each tab's back stack and scroll position.
- A top-level `route(...)` *outside* the `tabs(...)` node is full-page **above**
  the bar — see [Deep link to a detail screen](/raku_router/recipes/deep-link-detail/).
- "Tap the active tab to pop to root": call `tabs.activeStack.reset(initial)` in
  `onDestinationSelected` when the tapped index equals `tabs.index`.
