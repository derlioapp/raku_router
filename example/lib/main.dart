import 'package:flutter/material.dart';
import 'package:raku_router/raku_router.dart';

void main() => runApp(const ExampleApp());

// ---------------------------------------------------------------------------
// Screens are plain data classes — no code generation. You navigate by passing
// the object (`context.push(const Note('1'))`), never a string.
// ---------------------------------------------------------------------------

sealed class AppRoute extends RakuRoute {
  const AppRoute();
}

class Feed extends AppRoute {
  const Feed();
}

class Note extends AppRoute {
  const Note(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class Settings extends AppRoute {
  const Settings();
}

/// A guarded screen: while [dirty] is on it refuses to pop (back — including the
/// predictive-back swipe — is blocked), and explains why.
class EditProfile extends AppRoute with RouteGuard {
  const EditProfile();
  static final ValueNotifier<bool> dirty = ValueNotifier<bool>(false);

  @override
  bool get canPop => !dirty.value;

  @override
  Listenable? get rebuildOn => dirty; // re-evaluate canPop when dirty toggles

  @override
  void onPopBlocked(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Discard unsaved changes first.')),
    );
  }
}

/// A full-page route: lives above the tab shell, so it covers the bar.
class Photo extends AppRoute {
  const Photo(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

// ---------------------------------------------------------------------------
// One declarative route TREE: each node is "a URL ↔ a typed screen". The URL's
// structure rebuilds the navigation stack, so a deep link to /feed/notes/2 opens
// the Feed tab on that note *with Feed underneath* (back returns to the feed).
// Nested routes are children; tabs are a node; a top-level route sits full-page
// above the shell. The premium slide is the default transition. No code-gen.
// ---------------------------------------------------------------------------

final router = raku(
  initial: const Feed(),
  routes: [
    tabs(
      shell: (context, tabs, child) => Scaffold(
        body: child,
        bottomNavigationBar: ListenableBuilder(
          listenable: tabs,
          builder: (context, _) => NavigationBar(
            selectedIndex: tabs.index,
            onDestinationSelected: tabs.go,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.list), label: 'Feed'),
              NavigationDestination(
                icon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
      branches: [
        [
          route(
            '/feed',
            (_) => const Feed(),
            (_) => const FeedScreen(),
            children: [
              // /feed/notes/:id — nested, so it stacks on top of Feed.
              route(
                'notes/:id',
                (p) => Note(p('id')),
                (n) => NoteScreen(id: n.id),
              ),
            ],
          ),
        ],
        [
          route(
            '/settings',
            (_) => const Settings(),
            (_) => const SettingsScreen(),
            children: [
              route(
                'edit',
                (_) => const EditProfile(),
                (_) => const EditProfileScreen(),
              ),
            ],
          ),
        ],
      ],
    ),
    // A top-level route is full-page — it sits above the shell and covers the bar.
    route('/photo/:id', (p) => Photo(p('id')), (n) => PhotoScreen(id: n.id)),
  ],
);

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});
  @override
  Widget build(BuildContext context) =>
      MaterialApp.router(title: 'raku_router example', routerConfig: router);
}

// ---------------------------------------------------------------------------
// Screens — every navigation is a typed object; nested pushes stay in the tab,
// the full-page Photo covers the bar.
// ---------------------------------------------------------------------------

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feed')),
      body: ListView(
        children: [
          for (final id in ['1', '2', '3'])
            ListTile(
              title: Text('Note $id'),
              onTap: () => context.push(Note(id)), // nested — bar stays
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.photo),
            title: const Text('Open full-screen photo (covers the bar)'),
            onTap: () => context.push(const Photo('sunset')), // full-page
          ),
        ],
      ),
    );
  }
}

class NoteScreen extends StatelessWidget {
  const NoteScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Note $id')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: () => context.push(Note('$id-child')),
              child: const Text('Push a nested note'),
            ),
            TextButton(onPressed: context.pop, child: const Text('Back')),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: FilledButton(
          onPressed: () => context.push(const EditProfile()),
          child: const Text('Edit profile (guarded)'),
        ),
      ),
    );
  }
}

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: Center(
        child: ValueListenableBuilder<bool>(
          valueListenable: EditProfile.dirty,
          builder: (context, dirty, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Unsaved changes'),
                subtitle: Text(
                  dirty ? 'Back is BLOCKED.' : 'Toggle on to block leaving.',
                ),
                value: dirty,
                onChanged: (v) => EditProfile.dirty.value = v,
              ),
              TextButton(
                onPressed: context.pop, // honours the guard
                child: const Text('Try to go back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PhotoScreen extends StatelessWidget {
  const PhotoScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Full-screen photo: $id',
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
            TextButton(onPressed: context.pop, child: const Text('Close')),
          ],
        ),
      ),
    );
  }
}
