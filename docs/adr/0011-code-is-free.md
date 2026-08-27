# 11. `code/` is free

Date: 2026-08-26

## Status

Accepted. Amends [ADR 0004](0004-the-project-canon-is-executable.md), which made
the canon executable and, in doing so, made a recommendation enforceable without
anyone deciding that it should be.

## Context

The canon requires four directories inside `code/` — `infra`, `db`, `api`,
`app` — each with a README, and `project check` reports a missing one as an
**error** with exit `1`. Not a warning: `_fileCheck` returns
`CheckStatus.error` for any absent canonical file, and `check` exits non-zero
when any error is present.

The two projects that are meant to demonstrate the methodology both fail that
rule.

```text
inquiry                             macss
✗  code/infra/README.md  missing    !  code/books    not a canonical layer
✗  code/db/README.md     missing    !  code/linkedin not a canonical layer
✗  code/api/README.md    missing    !  code/prompt   not a canonical layer
✗  code/app/README.md    missing    !  code/site     not a canonical layer
!  code/book, linkedin, paper, site, vscode
```

Inquiry ships a CLI, a documentation site, a book and a VS Code extension. It
has no API and no database, and inventing them would not make it a better
project. macss itself carries four directories the canon calls suspicious. When
both reference implementations diverge from a rule in the same direction, the
rule is what is wrong.

**The two halves of the canon are not the same kind of thing.** What `docs/`
requires is *methodological*: a MACSS project must be able to explain itself, so
an ADR record, an architecture overview and a roadmap are demanded of every
project regardless of what it builds. What `code/` requires is *architectural*:
`infra` / `db` / `api` / `app` is one shape of solution — the most common one,
and a good default — but a shape nonetheless. ADR 0004 put both in the same
list, and the list is enforced, so a recommendation became a requirement without
that ever being decided.

The cost is not only a red mark. A project made to satisfy the rule ends up
holding `code/api/README.md` describing an API layer that does not exist. The
canon would be manufacturing documentation for absent things.

And the warning has its own version of the problem. `not a canonical layer`
fires on `site`, `book`, `vscode`, `linkedin`, `paper`, `prompt` — nine times
across the two projects, every one of them a deliberate, correct choice. A
warning that appears on correct configurations is noise, and noise is how a
signal stops being read.

## Decision

**Nothing inside `code/` is required, and nothing inside it is a deviation.**

`code/` itself stays canonical: the separation of code from documentation is the
rigid part, and it is what `docs/` nested inside a layer still gets reported
for. What lives under `code/` becomes the project's own business — that is what
lets MACSS articulate any software solution rather than one shape of one.

Concretely:

- The four layer READMEs leave `canonFiles`. `check` no longer reports them,
  `adopt` no longer creates them.
- The `not a canonical layer` warning is removed. There is no longer a list of
  approved directory names for a project to deviate from.
- The **relational** rules stay, and keep the shape they already had — they were
  written conditionally from the start. `_moduleMirrorChecks` opens with
  `if (apiModules.isEmpty) return const []`, so it never demanded an `api`
  layer; it says only that an `api/modules/sales` without a `db/modules/sales`
  is worth a look. A project that adopts the pattern is held to its internal
  consistency; a project that does not is not asked about it.
- The boundary rule stays: documentation nested inside a layer is still
  reported, because that is about `code/` versus `docs/`, which is canon.

**`project create` keeps stamping the four layers.** They move to a separate
list — `starterLayers` — that `create` consumes and `check` does not. A new
project still opens on the recommended shape, and deleting a directory that does
not apply costs nothing.

That leaves `create` producing more than `check` requires, which is the reverse
of the defect this module was built to prevent. The original was the book
requiring a root `CHANGELOG.md` that `create` never stamped: **check demanding
more than create produced**, which breaks a project the moment it is born. The
opposite direction is benign — an offer that can be declined.

Because it is benign but surprising, it is stated here and pinned by a test: a
freshly created project conforms, **and so does the same project with all four
layers deleted**. Without that second test, the next reader of `canon.dart` will
notice the asymmetry and "fix" it by putting the layers back.

**`adopt` does not stamp them.** `create` starts a project from a shape; `adopt`
retrofits an existing one to the canon, and the layers are no longer canon. An
`adopt` that added them would put back the very directories a project had
deliberately removed — which is exactly what would happen to inquiry today.

## Consequences

**Easier**

- A project is free to be a CLI, a book, an extension, a site, or all four,
  without either failing the check or accumulating warnings that mean nothing
- `check`'s output becomes worth reading again: what remains is a real finding
- The recommended architecture is still taught, by `create` and by the book,
  where a recommendation belongs

**Harder**

- `create` and `check` no longer read from one list, so "what a MACSS project
  is" is answered in two places. The distinction is real — *required* versus
  *offered* — and the names carry it, but it is one more thing to keep straight
- Nothing detects a project that meant to follow the common pattern and drifted
  out of it. That was never really detected anyway: the check only ever noticed
  the absence of a README, not whether the architecture held

**Deliberately left out**

- A `--layers` or `--minimal` flag on `create`. It would make the common case
  something to configure in order to get, and the cost it avoids is deleting a
  directory
- Any list of *recognized* directory names kept for reporting. Recognition
  without consequence is a list that goes stale, and the moment it exists
  somebody will want the unrecognized ones flagged again
