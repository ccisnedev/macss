---
name: macss-specification
description: Run the MACSS specification stage — turn a raw requisition into a healthy specification plus the issues it yields, deciding by evidence rather than inference.
---

## Goal

Turn a raw requisition (an email, a document, a chat thread) into a coherent,
actionable specification and the issues it yields — with every key decision
licensed by evidence, not by inference.

This is the stage that ends at Definition of Ready. It precedes implementation
and is owned by QA.

## Method

Decide by **evidence**, never by inference. For every decision you are unsure
of, run a **throwaway experiment**: read the database, run code in a container,
probe the API. These experiments validate a decision and are then discarded —
they are not product code.

Record each **technical** decision, with a re-checkable handle, in the *issues*.
The specification itself stays at the business level.

## Steps

1. `macss specification new <slug>` (add `--lang es` for Spanish) — the CLI
   scaffolds `docs/requisitions/<YYYYMMDD>-<slug>/requisition.md` and
   `specification.md` as a **git-ignored local workspace**, and records it as the
   **active requisition**, so later commands need no slug. Inputs and outputs are
   files on disk, not your memory.
2. Gather the raw requisition from **all** its sources into `requisition.md`
   (AS-IS / TO-BE). Capture exactly what was asked — do not invent scope.
3. Fill `specification.md`. It is a lean **business charter** written in the
   domain's language, not an implementation document: a committed delivery date,
   user stories each carrying at least one Given-When-Then acceptance criterion,
   an explicit scope that states what is *excluded*, and the domain glossary and
   business rules.
4. Derive the issues with `macss issue new <name> [--repo owner/repo]` — it
   scaffolds `issue-<name>.md` in the active requisition ("issue as code"),
   inheriting the specification's language. Fill each from evidence, and list the
   acceptance criteria it covers in the front-matter `covers:`, **each qualified
   by its user story** — `covers: [US1-AC1, US1-AC2, US2-AC3]`. Numbering
   restarts in every story, so a bare `AC-1` is ambiguous and traces nothing.
   One issue per unit of work: split only what can ship independently. A feature
   whose parts make no sense apart is one issue.
5. `macss specification check` — the CLI runs the `specification_ready` gate over
   the active requisition. Fix exactly what it reports, one violation at a time,
   until it exits 0. Do not skip a violation.
6. Dedup-check before creating: `gh issue list --search "<keywords>"`. If a
   too-similar issue already exists, edit that one instead.
7. `macss issue publish <name> --plan` previews the `gh issue create` built from
   the front-matter. Once the human approves, `--apply` creates it. The
   **published GitHub issues are the durable artifacts**; the requisition stays a
   local, git-ignored workspace.
8. Present the specification and its issues to the human for review.

## Done when

- [ ] `requisition.md` captures the need (AS-IS / TO-BE) from every source.
- [ ] `specification.md` is filled — the CLI's gate is the authority on what
      "filled" means; run it rather than guessing.
- [ ] `macss specification check` exits 0.
- [ ] At least one `issue-<name>.md` is derived, dedup-checked, and traces every
      acceptance criterion.
- [ ] The specification is presented to the human for review.
