---
title: Getting started
description: Install raku_router and render your first reactive navigation stack.
---

## Install

```bash
flutter pub add raku_router
```

raku_router needs only `flutter` — no state-management or design-system dependency.

## Your routes are data

Define routes as a `sealed` hierarchy so the `switch` that maps them to screens
is checked for exhaustiveness by the compiler. No code generation.

```dart
sealed class AppRoute extends RakuRoute {
  const AppRoute();
}
class Home extends AppRoute { const Home(); }
class NoteDetail extends AppRoute {
  const NoteDetail(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}
```

## Render a stack (no deep linking)

A `RouteStack` is a reactive `List<route>`. Drop a `RouteStackView` into
`MaterialApp.home` (or any design system's shell):

```dart
final stack = RouteStack(const Home());

MaterialApp(
  home: RouteStackView(
    stack: stack,
    builder: (context, route) => switch (route as AppRoute) {
      Home()                => const HomeScreen(),
      NoteDetail(:final id) => NoteScreen(id: id),
    },
  ),
);
```

## Navigate from anywhere

No constructors to thread — read the nearest stack from the context:

```dart
context.push(const NoteDetail('42'));
context.pop();
```

## Next

- Add URLs and deep linking with the **[route tree](/raku_router/guides/route-tree/)**.
- Give each tab its own back stack with **[tabs](/raku_router/guides/tabs/)**.
- Try it live in the **[demo](/raku_router/live-demo/)**.
