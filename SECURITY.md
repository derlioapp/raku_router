# Security policy

## Supported versions

Security fixes land on the latest released version of `raku_router`. Please
upgrade before reporting.

## Reporting a vulnerability

Please **don't open a public issue**. Report it privately through GitHub's
[security advisories](https://github.com/derlioapp/raku_router/security/advisories/new)
with a description, the affected version, and a minimal reproduction (a route
tree plus the URL or steps that trigger it).

You'll get an acknowledgement within a few days. Once a fix is released, the
advisory is published with credit, unless you'd rather stay anonymous.

## Scope

A router's attack surface is the **URL**: a deep link, the browser's address
bar, a QR code, or a push payload can carry any string. These are in scope:

- a URL that crashes the app or hangs navigation;
- a URL that bypasses a `RouteGuard` or `RouteRedirect` (e.g. reaching a
  protected screen while signed out);
- a URL that makes route → URL (`hrefOf` / `uriOf`) produce a different
  location than it parses from.

Out of scope: what your own `parse` / `screen` code does with the typed values
it receives. Treat URL parameters as untrusted input in your app, exactly as you
would form input.
