---
name: macss-execute
description: Run the execute phase of a MACSS implementation cycle by hand — implement the plan phase by phase under TDD, without the scheduler agent.
---

## Goal

Implementation under plan constraints. Work the plan **phase by phase**; each
phase produces tested code and a commit.

Implementation is driven by the inquiry state machine. This skill runs its
execute phase manually; the CLI remains the authority on what the phase requires.

## Steps

1. `iq fsm state --json` — confirm you are in EXECUTE and do exactly what its
   `next` field says. Use only the events it lists.
2. `iq ape prompt --name ada` — read the method for this phase and apply it.
3. Implement the plan **phase by phase**. For each phase: write the test
   **first** — it must prove the acceptance criterion the phase covers — then the
   code, keep the full test suite green, and commit. The full suite must pass
   before any commit, independent of the plan's own verification criteria. Then
   do the release preparation the plan specifies: version bump, CHANGELOG, and a
   final commit.
4. `iq fsm transition --event finish_execute` — the CLI verifies the result. If
   it fails, fix exactly what the error reports. Do not re-run the event
   unchanged.
5. When the gate passes, present the result to the human and stop. The human
   approves moving on.

## Done when

- [ ] The plan is implemented and the full test suite passes.
- [ ] `iq fsm transition --event finish_execute` exits 0.
