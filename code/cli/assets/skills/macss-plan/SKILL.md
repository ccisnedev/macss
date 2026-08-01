---
name: macss-plan
description: Run the plan phase of a MACSS implementation cycle — turn the diagnosis into staged work, each stage carrying an executable verification.
---

## Goal

Turn the diagnosis into a staged plan: divide the work into phases, order them
by dependency, and define how each one is verified.

No code is written in this phase. Writing code here is how a plan becomes
decoration.

## Method

**Order by the MACSS vertical.** Work flows bottom-up through the layer cake:
`db → api → app`, with `infra` beneath them. A phase that needs a layer below it
comes after that layer, never before.

**Every phase carries an executable check** — a test-runner command or a
test-file reference, not prose and not pseudocode. A phase you cannot verify is
a phase you cannot call done. The plan ends with a final phase that runs the
**full** suite, not only the tests the change touched.

**Enumerate construction sites, not just call sites.** When a phase changes a
shared interface or type shape, list every place that type is *constructed* —
object literals, factory returns, dispatchers, adapters — not only the places
that consume or import it. Name the concrete search that will find them; that
search is part of the plan.

**Trace to the acceptance criteria.** Each phase states which AC it advances.
An AC no phase covers is scope you are about to miss.

## Steps

1. Read the diagnosis. The plan answers what it found; a plan that ignores it is
   solving a different problem.
2. Split the work into phases, each independently verifiable and each small
   enough to leave the suite green.
3. Order them by dependency, along the MACSS vertical.
4. Give every phase its executable verification check and the AC it covers.
5. Add the final full-suite phase, plus whatever release preparation the change
   needs — version bump, CHANGELOG entry.
6. Write the plan to disk and present it to the human for approval before any
   code is written.

## Done when

- [ ] Every phase references the diagnosis's findings.
- [ ] Every phase has an executable verification check, and one runs the full
      suite.
- [ ] Every acceptance criterion is covered by at least one phase.
- [ ] Phase order respects the layer dependencies.
- [ ] The human approved the plan.
