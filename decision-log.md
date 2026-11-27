# Decision log

Every added, changed or removed rule, newest last:
date · document · old → new · why · source.

Labels on rules: source `user` (stated or approved by the maintainer) or
`agent`; strength `firm` (changes need the maintainer's approval),
`suggestion` (the default; deviate for a better reason and say so) or
`convention` (how it has been done so far).

- 2026-11-27 · design/road-to-1.0.md · Automatic pub.dev publishing on tag
  push (`publish.yaml`, GitHub Actions) → manual publishing with
  `flutter pub publish`; `publish.yaml` removed. Why: the maintainer decides
  and runs every release by hand. Source: user.
- 2026-11-27 · .gitignore / .pubignore · `feedback/` committed to git (kept
  out of the package) → ignored by both git and pub. Why: incoming app
  feedback is working material, not part of the repository. Source: user.
- 2026-11-27 · design/road-to-1.0.md · Release command `flutter pub publish`
  → `dart pub publish`. Why: the `flutter` wrapper didn't pass the
  confirmation answer through, so publishing hung. Source: user.
