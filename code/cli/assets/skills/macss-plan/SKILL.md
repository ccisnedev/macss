---
name: macss-plan
description: Run the plan phase of a MACSS implementation cycle by hand — design the staged plan from the diagnosis, without the scheduler agent.
---

## Goal

Experimental plan design from the diagnosis. Divide the work into phases, order
them by dependency, and define the verification criteria for each phase.

Implementation is driven by the inquiry state machine. This skill runs its plan
phase manually; the CLI remains the authority on what the phase requires.

## Steps

1. `iq fsm state --json` — confirm you are in PLAN and do exactly what its `next`
   field says. Use only the events it lists.
2. `iq ape prompt --name descartes` — read the method for this phase and apply
   it.
3. The CLI has already scaffolded the plan artifact. **Open it and fill every
   section** with real content, replacing every placeholder. Inputs and outputs
   are files on disk, not your memory. Every phase must reference the diagnosis's
   decisions. When a phase changes a shared interface or type shape, enumerate
   every **construction** site for that type — object literals, factory returns,
   dispatchers and adapters — not just the consumer and import sites, and name
   the concrete search strategy that will find them. No code edits here; that is
   the execute phase.
4. `iq fsm transition --event approve_plan` — the CLI verifies the result. If it
   fails, fix exactly what the error reports. Do not re-run the event unchanged.
5. When the gate passes, present the result to the human and stop. The human
   approves moving on.

## Done when

- [ ] The plan is filled — no scaffold placeholders remain.
- [ ] `iq fsm transition --event approve_plan` exits 0.
