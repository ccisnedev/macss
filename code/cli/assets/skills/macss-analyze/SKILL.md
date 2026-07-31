---
name: macss-analyze
description: Run the analyze phase of a MACSS implementation cycle by hand — build shared understanding and produce the diagnosis, without the scheduler agent.
---

## Goal

Shared problem understanding before planning. Investigate the problem, build that
understanding **with the user**, and produce the diagnosis that is the sole input
to planning.

Implementation is driven by the inquiry state machine. This skill runs its
analyze phase manually; the CLI remains the authority on what the phase requires.

## Steps

1. `iq fsm state --json` — confirm you are in ANALYZE and do exactly what its
   `next` field says. Use only the events it lists.
2. `iq ape prompt --name socrates` — read the method for this phase and apply it.
3. The CLI has already scaffolded the diagnosis artifact. **Open it and fill
   every section** with real content, replacing every placeholder. Inputs and
   outputs are files on disk, not your memory. Inspect repository state, existing
   cycle artifacts, project docs, and relevant tests or runtime evidence *before*
   asking the user for missing facts; ask only for what evidence cannot recover.
4. `iq fsm transition --event complete_analysis` — the CLI verifies the result.
   If it fails, fix exactly what the error reports. Do not re-run the event
   unchanged.
5. When the gate passes, present the result to the human and stop. The human
   approves moving on.

## Done when

- [ ] The diagnosis is filled — no scaffold placeholders remain.
- [ ] `iq fsm transition --event complete_analysis` exits 0.
