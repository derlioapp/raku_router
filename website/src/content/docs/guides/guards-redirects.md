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
back button in Router mode — and, on the **web**, the browser's back/forward
buttons: a URL change that would remove a guarded page is vetoed, `onPopBlocked`
runs, and the address bar is put back. (A URL change that leaves the page alive —
switching to another tab — goes through; the page keeps its state.)

The `context` passed to `onPopBlocked` belongs to the guarded page's own stack,
so a confirming `context.pop()` pops that page. An explicit `router.go(...)` /
`context.go(...)` is an app decision, not a back gesture, so guards don't veto
it.

## RouteRedirect — resolve before showing

Return a different route to redirect, or `null`/the same destination to stay.
Redirect chains are followed and **loop-protected** by the package — you don't
hand-write the "am I already going there?" check. Redirects resolve on `push`, on
`go`, *and* when reached via a deep link.

```dart
class LegacyNote extends AppRoute with RouteRedirect {
  const LegacyNote(this.id);
  final String id;
  @override
  RakuRoute redirect() => NoteDetail(id); // resolved before it's shown
}
```

### A redirect protects its whole subtree

A deep link rebuilds the entire ancestor chain, and **every** redirect on that
chain applies — not only the leaf's. So one redirect on a section root guards
every URL below it:

```dart
class Admin extends AppRoute with RouteRedirect {
  const Admin();
  @override
  RakuRoute? redirect() => auth.isAdmin ? null : const Login();
}

route('/admin', (_) => const Admin(), (_) => const AdminScreen(), children: [
  route('users/:id', (p) => User(p('id')), (u) => UserScreen(u)),
]);
// /admin/users/1 while signed out → Login (not UserScreen over AdminScreen).
```

The outermost redirecting ancestor wins, and loops across ancestors are caught
like any other redirect loop.
