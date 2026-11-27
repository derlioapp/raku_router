---
title: Build a notes app
description: A hands-on tour of raku_router — from a single screen to tabs, a detail screen, a guard, and deep linking.
---

import { Steps } from '@astrojs/starlight/components';

We'll build a small notes app and add one raku_router concept at a time: a route
tree, a typed detail screen, tabs with their own back stacks, an unsaved-changes
guard, and deep linking. By the end you'll have the app you see in the
[live demo](/raku_router/live-demo/).

<Steps>

1. **Install and define your routes as data.**

   ```bash
   flutter pub add raku_router
   ```

   Routes are a `sealed` hierarchy, so the `switch` that builds screens is checked
   for exhaustiveness — no code generation.

   ```dart
   sealed class AppRoute extends RakuRoute { const AppRoute(); }
   class Feed extends AppRoute { const Feed(); }
   class Note extends AppRoute {
     const Note(this.id);
     final String id;
     @override
     List<Object?> get props => [id];
   }
   class Settings extends AppRoute { const Settings(); }
   ```

2. **Declare the route tree and run it.**

   Each `route(path, parse, screen)` ties a URL to a typed route and its screen.
   A child's path extends its parent's, so it stacks on top.

   ```dart
   final router = raku(
     initial: const Feed(),
     routes: [
       route('/feed', (_) => const Feed(), (_) => const FeedScreen(), children: [
         route('notes/:id', (p) => Note(p('id')), (n) => NoteScreen(id: n.id)),
       ]),
     ],
   );

   void main() => runApp(MaterialApp.router(routerConfig: router));
   ```

3. **Navigate by typed object.**

   From any screen below the router, push a route — no constructors to thread.
   The address bar follows automatically.

   ```dart
   // inside FeedScreen, on a note tap:
   onTap: () => context.push(Note(note.id)),
   ```

   Opening `/feed/notes/42` now rebuilds `[Feed, Note(42)]`, so **back returns to
   the feed** — that's deep linking from the tree's structure.

4. **Add tabs with their own back stacks.**

   Wrap your top-level routes in a `tabs(...)` node. Each branch keeps its own
   history; `context.push` of a tab route stays inside the active tab.

   ```dart
   raku(
     initial: const Feed(),
     routes: [
       tabs(
         shell: (context, tabs, child) => Scaffold(
           body: child,
           bottomNavigationBar: NavigationBar(
             selectedIndex: tabs.index,
             onDestinationSelected: tabs.go,
             destinations: const [/* Feed, Settings */],
           ),
         ),
         branches: [
           [route('/feed', (_) => const Feed(), (_) => const FeedScreen(), children: [
             route('notes/:id', (p) => Note(p('id')), (n) => NoteScreen(id: n.id)),
           ])],
           [route('/settings', (_) => const Settings(), (_) => const SettingsScreen())],
         ],
       ),
     ],
   );
   ```

5. **Guard a screen with unsaved changes.**

   Mix `RouteGuard` into a route. `canPop` is read synchronously (predictive back
   needs a sync answer); `onPopBlocked` lets you confirm.

   ```dart
   class EditNote extends AppRoute with RouteGuard {
     const EditNote(this.id);
     final String id;
     @override
     List<Object?> get props => [id];
     @override
     bool get canPop => !hasUnsavedChanges;
     @override
     void onPopBlocked(BuildContext context) {
       // show a "discard changes?" dialog
     }
   }
   ```

   The guard is honoured by **every** back path: the predictive-back gesture, the
   system back button, and `context.pop()`.

6. **Ship it to the web.**

   The router already drives the browser's address bar and back/forward. For clean
   paths instead of the `#` hash, opt in once in `main()`:

   ```dart
   import 'package:flutter_web_plugins/url_strategy.dart';

   void main() {
     usePathUrlStrategy();
     runApp(MaterialApp.router(routerConfig: router));
   }
   ```

</Steps>

## Where to go next

- **[Concepts](/raku_router/concepts/mental-model/)** — how the URL ⇄ stack mapping and tab
  state preservation actually work.
- **[Recipes](/raku_router/recipes/bottom-nav/)** — copy-paste solutions for common tasks.
- **[Guides](/raku_router/guides/route-tree/)** — the reference for each feature.
