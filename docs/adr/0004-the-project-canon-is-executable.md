# 4. The project canon is executable

Date: 2026-07-31

## Status

Accepted. Two things this ADR describes in the present tense have since changed,
and the decision body is left as written because it records what was decided:

- The deprecated root-level `macss create` alias was removed in 0.5.0, one minor
  version after 0.3.0 shipped it — as this ADR anticipated.
- `macss issue publish`, cited here for the `--plan` / `--apply` convention, no
  longer exists. The convention outlived it: `requisition publish` and
  `specification publish` follow it.

## Context

`code/book/src/project-structure.md` states that the MACSS directory structure
"is not decorative — it is architecture visible", and closes with four
invariants written as rules:

```
- If `api/modules/X` exists, `db/modules/X` must also exist.
- Client modules mirror backend modules by name.
- Documentation is never mixed with code.
- Decisions are recorded near the architecture they affect.
```

Nothing verified any of them. The canon existed as prose, and `macss create`
materialized it from a separate list kept inside the command.

Two independent definitions of the same thing drift, and this pair had already
drifted: the book requires a root `CHANGELOG.md` — it appears in the tree diagram
and in the paragraph describing what `macss create` produces — while
`create.dart` stamped only `README.md`, `.gitignore` and `.gitattributes`.
**The scaffolder did not produce a project satisfying its own documented canon,
and nothing could detect that.**

There was also no answer for the common case. `create` assumes an empty
directory. A team with an existing repository that wants to adopt MACSS had
nothing to run.

## Decision

The canon becomes a single executable definition, in `canon.dart`, consumed by
three commands grouped under a `project` module:

```text
macss project create   # from nothing: scaffold the canonical structure
macss project check    # diagnose: what is missing, what deviates
macss project adopt    # retrofit: bring an existing project to the canon
```

`create` moves here from the global module. It is the entry point to the whole
methodology but was a bare root-level command; the CLI grammar reserves modules
for nouns and verbs for leaf actions, so `init` could not be the module name and
`project` — already the vocabulary's noun — is. `macss create` remains a
deprecated alias for one minor version.

Findings are reported in two categories, which call for different responses:

| Status | Meaning | Acted on by |
|---|---|---|
| `error` | A required file is **missing** | `adopt --apply` creates it |
| `warning` | Something is **extra or deviates** | Nothing. A human decides |

A `warning` never fails the command.

**`adopt` never deletes.** It only creates what the canon requires and the
project lacks, and it never overwrites. It previews by default, following the
`--plan` / `--apply` convention `macss issue publish` already uses.

## Consequences

**The scaffolder is now verifiable against its own standard.** The module's
acceptance criterion is that `macss project check` on a freshly created project
exits 0, which is asserted by a test. The `CHANGELOG.md` gap is closed, and that
class of drift cannot recur silently: changing the canon means changing one
list that all three commands read.

**Deviations are surfaced, never corrected.** An `api` module without its data
module, a client module mirroring nothing, a stray directory under `code/`,
documentation nested inside a layer — each is reported with what the rule is and
left alone. A `code/legacy/` directory may be deliberate debt, and a tool has no
context to decide that. Creating an empty mirror directory would satisfy the
letter of an invariant while hiding the question worth asking.

**"Documentation is never mixed with code" is checked narrowly**, in its one
unambiguous form: a `docs/` directory nested inside a layer. The rule is broader
than what is verifiable, and claiming to check more than we do would be worse
than checking less.

**`macss doctor` and `macss project check` stay distinct.** Doctor is the doctor
of the CLI — its binary, its assets, its external toolchain. `project check` is
about a project. They share the reporting shape in `src/checks.dart` so they read
alike, but conflating them under one `doctor` name would have confused two
different scopes.

## References

- `code/book/src/project-structure.md` — the canon these commands verify
- `docs/roadmap.md`, Stage 5 — the inception stage and the `project` module
- ADR 0002 — explicit flags over positional args, which `--path` follows
