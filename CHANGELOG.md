## 0.1.0

First public release — a tiny, code-generation-free, UI-agnostic router for
Flutter.

Highlights:

- **Type-safe routes, no codegen** — routes are plain `sealed` classes; an
  exhaustive `switch` is your route table.
- **Declarative deep linking** — `raku(routes: […])` maps a URL's structure
  to a typed navigation stack, both ways, with no hand-written parsing.
- **Nested tabs built in** — each branch keeps its own persistent back stack and
  tabs nest arbitrarily.
- **Guards & redirects** — `RouteGuard` (predictive-back aware) and
  loop-protected `RouteRedirect`.
- **Built-in transitions** — `slideIn`, `none`, `fade`, `slide`, `riseUp`, all
  Material/Cupertino-free.
- **No dependencies beyond `flutter`** — no state-management or design-system
  coupling. Supports all 6 platforms; WASM-ready. SDK floor: Dart 3.6 /
  Flutter 3.27.
