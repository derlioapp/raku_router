---
title: Guards & redirects
description: Veto a pop with RouteGuard; resolve a destination before it's shown with RouteRedirect.
---

Guards and redirects are *control flow on the route itself* — mix them into a
route class.

## RouteGuard — veto a pop

`RouteGuard` lets a screen refuse to be popped (e.g. unsaved changes). `canPop`
is a **synchronous** getter — predictive back needs a sync answer — and raku_router
wraps the guarded screen in a `PopScope`, so it is honoured by **every** back
path: the predictive-back gesture, an imperative `Navigator.pop`, the system back
button, and `context.pop()`.

```dart
class Editor extends AppRoute with RouteGuard {
  const Editor();
  @override
  bool get canPop => !hasUnsavedChanges; // false blocks the pop

  @override
  Listenable? get rebuildOn => formState; // re-evaluate canPop as state changes

  @override
  void onPopBlocked(BuildContext context) {
    // Confirm here — e.g. show a "discard changes?" dialog.
  }
}
```

`onPopBlocked` fires on every blocked back path, including the discrete system
back button in Router mode.

## RouteRedirect — resolve before showing

Return a different route to redirect, or `null`/the same destination to stay.
Redirect chains are followed and **loop-protected** by the package — you don't
hand-write the "am I already going there?" check. Redirects resolve on `push`
*and* when reached via a deep link.

```dart
class LegacyNote extends AppRoute with RouteRedirect {
  const LegacyNote(this.id);
  final String id;
  @override
  RakuRoute redirect() => NoteDetail(id); // resolved before it's shown
}
```
