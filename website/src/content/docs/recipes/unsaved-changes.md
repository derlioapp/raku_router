---
title: Unsaved-changes guard
description: Block back navigation while a form is dirty, and confirm before discarding.
---

**Goal:** while an editor has unsaved changes, block back — gesture, system
button, and `context.pop()` alike — and show a "discard?" dialog.

Mix `RouteGuard` into the route. `canPop` is read **synchronously** (predictive
back needs a sync answer); `rebuildOn` re-evaluates it as state changes;
`onPopBlocked` runs when a blocked back is attempted.

```dart
class Editor extends AppRoute with RouteGuard {
  const Editor();

  @override
  bool get canPop => !formState.isDirty;

  @override
  Listenable? get rebuildOn => formState; // re-check when the form changes

  @override
  void onPopBlocked(BuildContext context) async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: const Text('Discard unsaved changes?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Discard')),
        ],
      ),
    );
    if (discard == true) {
      formState.reset();          // clears isDirty → canPop becomes true
      if (context.mounted) context.pop();
    }
  }
}
```

**Notes**

- raku_router wraps a guarded screen in a `PopScope`, so the guard is honoured by the
  predictive-back gesture, an imperative `Navigator.pop`, the system back button,
  and the Router's `popRoute` — `onPopBlocked` fires on all of them.
- For redirecting *into* a screen (e.g. auth), use a
  [redirect](/raku_router/recipes/auth-gate/) instead.
