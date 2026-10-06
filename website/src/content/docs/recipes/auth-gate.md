---
title: Auth / redirect gate
description: Send unauthenticated users to a login screen before a protected route is shown.
---

**Goal:** a protected route that bounces to `/login` when the user isn't signed
in. Use `RouteRedirect` — it resolves *before* the screen is shown, on both push
and deep-link entry, and is loop-protected.

```dart
class Dashboard extends AppRoute with RouteRedirect {
  const Dashboard();
  @override
  FutureOr<RakuRoute?> redirect() =>
      auth.isSignedIn ? null : const Login(); // null = stay
}
```

A deep link to `/dashboard` while signed out lands on `Login`; once signed in, it
shows the dashboard. No manual guard wiring at the call site.

The redirect also covers everything **nested under** `Dashboard`: a link to
`/dashboard/reports/7` is redirected too, because every route on a deep link's
path is checked.

**Redirect after login**

Keep the intended destination and push it once auth succeeds:

```dart
class Login extends AppRoute {
  const Login({this.then});
  final RakuRoute? then;
  @override
  List<Object?> get props => [then];
}

// in LoginScreen, on success — `go` rebuilds the location (back stack, tab):
context.go(widget.route.then ?? const Dashboard());
```

Carry the destination as a **typed route**, not a `?next=` URL string: a route
object can only point inside your app, so there's no open-redirect to guard
against.

**Sign-out**

Redirects run when a route is *entered*, so on sign-out navigate away
explicitly. Keep the `RakuRouter` that `raku(...)` returns and listen to your
auth state — no `BuildContext` needed:

```dart
final router = raku(initial: const Home(), routes: [...]);

auth.addListener(() {
  if (!auth.isSignedIn) router.go(const Login());
});
```

`go` isn't vetoed by `RouteGuard`s — signing out is an app decision, not a back
gesture.

**Notes**

- `redirect()` returns `FutureOr`, so you can `await` an async auth check.
- Chains are followed and loop-protected — returning a route that itself
  redirects is fine; raku_router won't spin.
- For *blocking a pop* (not entry), use a [guard](/raku_router/recipes/unsaved-changes/)
  instead.
