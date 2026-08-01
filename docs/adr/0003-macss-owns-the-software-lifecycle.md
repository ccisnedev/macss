# 3. MACSS owns the software lifecycle

Date: 2026-07-31

## Status

Accepted

## Context

MACSS is an architecture **and** an engineering methodology. The lifecycle it
defines is documented in the engineering handbook:

```
requisition → specification → issue → implementation → verification → deploy
```

The CLI expressed only the architecture half. It scaffolded the canonical
structure and tooled a subsystem; nothing in it carried a lifecycle stage.

Meanwhile `inquiry` — designed as the state machine for **one** of those stages,
driving an already specified issue through `analyze → plan → execute` — had
absorbed the rest. It shipped `iq specification` and `iq issue`, which are
pre-implementation work owned by QA, and it deployed the skills for every stage.
Its roadmap planned an `iq requisition` and an `iq verification` module.

The split was inverted: inquiry carried the vocabulary of a lifecycle it does not
define, and MACSS, which defines it, executed none of it.

A further asymmetry made the arrangement unstable. **MACSS is in production**; it
has to work for someone who installs nothing else. **Inquiry is a scientific and
engineering project**, free to change its FSM at its own pace. Whatever coupled
them would make the production tool hostage to the experimental one.

## Decision

The lifecycle stages move to the `macss` CLI. Inquiry returns to being the state
machine for the implementation stage alone.

1. `specification` and `issue` — commands, gate, templates and workspace helpers
   — move to MACSS.
2. The lifecycle skills move to MACSS as **static** `SKILL.md` assets. Inquiry's
   generative `SkillBuilder`, which assembled them from FSM contracts at deploy
   time, is not replicated: copying it would duplicate the FSM assets in another
   repository.
3. The skills are **self-contained and never reference inquiry** — not as a
   step, not as an optional enhancement. Naming a second CLI inside a production
   tool's instructions is an invitation to install it.
4. Skills are installed **once per machine**, into each assistant's own directory
   under `~/`, not per repository.
5. The relationship is **one-directional**: inquiry is the laboratory where the
   method is refined under enforced gates; MACSS inherits the result when a human
   ports it into a skill.

## Consequences

**The implementation stage appears in both, deliberately.** This is a split, not
a fork, because of what is and is not shared:

> Doctrine can safely live in two places; a contract cannot.

What is shared is doctrine — `analyze → plan → execute`, already written down in
the engineering handbook. What is never shared is the contract: no gate rule,
event name or artifact schema is restated in MACSS. Inquiry can rewrite its FSM
entirely without touching anything here.

**The cost is a manual sync point.** An improvement proven in the laboratory does
not reach MACSS until someone writes it into a `SKILL.md`. This is deliberate:
editorial, at human pace, decided by a person — and it is what buys MACSS the
ability to stand alone.

**Two on-disk formats are namespaced to MACSS.** The active-requisition pointer
moves from `.inquiry/` to `.macss/`, and templates emit `macss:lang` and
`kind: macss-issue`. Documents written with the previous `iq:lang` keep
resolving, and `--slug` resolves a requisition folder without the pointer, so no
work in flight is stranded.

**Building either of two things would undo this.** An `iq specification` module
re-absorbs what inquiry handed over. A `macss fsm` re-absorbs the laboratory.
A `macss implementation` module that drives the method without an engine is
compatible, and is left open.

## References

- `docs/lifecycle-migration-plan.md` — the operational plan and migration catalog
- `docs/roadmap.md`, Stage 5 — the lifecycle module surface
- ccisnedev/macss#4, ccisnedev/inquiry#299 — the two halves of the handover
