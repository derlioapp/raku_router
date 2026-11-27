# raku_router — road to 1.0

Current state: 187 tests, 100% line coverage, pana 160/160 enforced in CI, an
SDK-floor job (Flutter 3.27), a Material/Cupertino import guard, warning-free
dartdoc, and a docs site. A pre-1.0 review (architecture / product / security /
quality) was done; every code-side item is closed (see CHANGELOG → *0.3.0*).
The one big piece of work left is field validation.

## Done ✅

### Bugs (each reproduced, then fixed with a regression test)

- **A malformed deep link crashed the app** (security). If `parse` throws
  (`asInt`, `Enum.byName`) or the percent-encoding is invalid, that route now
  simply doesn't match → catch-all / `onUnknown`. Covered by a 2000-URL fuzz
  test.
- **An ancestor's redirect was skipped on deep links** (security). A sign-in
  redirect on `/admin` could be bypassed with a link to `/admin/users/1`. Every
  route on the rebuilt path now has its redirect applied.
- **The browser back button bypassed `RouteGuard` on the web.** It's now vetoed:
  `onPopBlocked` runs and the address bar is put back.
- **System back with a dialog/sheet open also closed the page underneath.** The
  overlay now closes first (root navigator, tab navigator, plain
  `RouteStackView`).
- **Declaring the same route type twice was silently overwritten** → assert.
- **The tab title went stale** → `raku(title:)` fallback.
- **Async redirect race** (a slow redirect overwrote a newer navigation) →
  ticket.

### API & product

- **URL → route and navigation without a context** (old item #1):
  `RakuRouter.go / push / current / routeOf` + `context.go`. Sign-out/sign-in
  and push-notification flows are covered with no extra concept
  (`refreshListenable` etc.).
- **Restoring inactive tabs** (old #2): documented as a deliberate limit (state
  restoration guide).
- **Dialogs / bottom sheets** (old #3): behaviour fixed + tests + README.
- **Results from pop** (old #4): recipe in the README.
- **Undefined edge behaviour** (old #5): case-sensitive matching, trailing and
  doubled slashes ignored, fragment ignored, last value wins for a repeated
  query key — documented and tested.
- **API freeze audit** (old #6): internals (`RouteTree`, `*Match`,
  `RakuNavigator`, stack internals) removed from the exports;
  `sameDestination` deleted; value types are `final`; one default transition
  (`slideIn`) everywhere.
- **`currentRoute` ValueListenable** → `router.current`.
- **go_router comparison / migration table** is up to date in the README.
- **Web URL strategy documentation** is in place.

### Security & process

- `SECURITY.md` (private reporting channel + scope).
- GitHub Actions pinned by SHA, CI runs with `permissions: contents: read`, the
  pana version is pinned, Dependabot (actions + pub, monthly).
- [user · firm] **Publishing is manual** — the maintainer runs
  `flutter pub publish` locally; no CI job publishes. Why: the maintainer wants
  to decide and run every release by hand.

### Releasing (manual)

1. Bump `version:` in `pubspec.yaml` and add the `CHANGELOG.md` entry.
2. Clean `main` with CI green: `git status` empty; analyze
   (`--fatal-infos --fatal-warnings`), `flutter test`, `dart format` and
   `tool/check_forbidden_imports.sh` pass.
3. `flutter pub publish --dry-run` → `Package has 0 warnings`, and the file
   list holds no repo-only files (see `.pubignore`).
4. `flutter pub publish`, then tag the published commit:
   `git tag vX.Y.Z && git push origin vX.Y.Z`.

## Remaining

1. **Publish `0.3.1`** manually (version and CHANGELOG are ready).
2. **Field validation:** publish `1.0.0-rc.1`, dogfood it in a real app, collect
   issues for a few weeks, then stamp `1.0`.
3. **pub.dev screenshots/GIF** (pubspec `screenshots:`) — a tabs + deep-link
   demo.

## Deliberately not adding (simplicity)

Awaited results from pop, a global redirect/middleware, `refreshListenable`,
async guards, named routes, regex/optional params, modelling dialogs as routes,
more transition animations. Rationale: each is either already solved by an
existing primitive (`go`, `RouteRedirect`, shared state) or would grow the core.
