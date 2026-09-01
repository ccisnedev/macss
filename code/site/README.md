# `macss_site`

[macss.ccisne.dev](https://macss.ccisne.dev), as source rather than as output. A
[Jaspr](https://jaspr.site) app: the pages are Dart components and the CSS is
generated from typed Dart.

Two routes — `/` and `/modular-api` — pre-rendered to HTML at build time.

## It ships no JavaScript

No component is annotated `@client`, so neither built page contains a `<script>`
tag. That includes the router: `jaspr_router` in static mode resolves the routes
during the build, and the links between them are ordinary links.

The old site had a 44-line `main.js` for a copy button and OS tabs. Both are
gone — see the design system's journal for what that cost and why.

## Building

```bash
dart pub global activate jaspr_cli
jaspr serve                          # http://localhost:8080
jaspr build                          # → build/jaspr/
```

`build/jaspr/packages/` is emitted by `build_web_compilers` and referenced by
nothing, since there is no client entrypoint. It is dropped before publishing.

## The design system is a pinned commit

[`design_system`](https://github.com/ccisnedev/design_system) arrives as a git
dependency pinned to a commit — not a path, which would need a sibling checkout
no runner performs, and not a version, because `publish_to: none` over there is
deliberate.

A change over there does not reach this site until that `ref` moves, and moving
it is a commit here, which triggers the deploy like any other.

To work on both at once, add a `pubspec_overrides.yaml` (git-ignored):

```yaml
dependency_overrides:
  design_system:
    path: ../../../design_system/code/design_system
```

## `web/` is copied verbatim

`CNAME`, the installers, the images — and `modular-api.html`, which is a
redirect: that page used to live at `/modular-api.html` and now lives at
`/modular-api/`. Links to the old address exist outside this repository.
