---
name: macss-execute
description: Run the execute phase of a MACSS implementation cycle — implement the plan phase by phase under TDD, keeping the suite green.
---

## Goal

Implement the plan **phase by phase**. Each phase produces tested code and a
commit.

## Method

**The test comes first.** For each phase, write the test before the code, and
write it so it proves the acceptance criterion the phase covers. A test written
after the code tends to describe what the code does rather than what the change
was for.

**The full suite must pass before every commit** — the whole project's tests,
not only the ones this phase touched, and independent of whatever the plan's own
verification criteria say. A phase that leaves the suite red is not done.

**Never weaken a sensor to make it green.** Do not lower a threshold, disable a
job, add a skip, or loosen an assertion to get past a failure. A gate that goes
green without the problem being solved is worse than a red one: it removes the
signal that would have caught it. If a test is wrong, fix it deliberately and
say so.

**A flaky test is a bug**, not noise to be re-run.

**Behind a feature flag, OFF must be identical to `main`.** Code can ship inert.
Dependencies point from the feature to the base, never the reverse.

## Steps

1. Take the next phase from the plan. Work them in order; the order encodes the
   layer dependencies.
2. Write the test that proves the phase's acceptance criterion. Watch it fail.
3. Write the smallest code that makes it pass.
4. Run the full suite. Fix what broke — do not proceed on red.
5. Commit the phase.
6. Repeat until every phase is done, then do the release preparation the plan
   specifies: version bump, CHANGELOG entry, final commit.
7. Present the result to the human.

## Done when

- [ ] Every plan phase is implemented and committed.
- [ ] Every acceptance criterion is covered by at least one test.
- [ ] The full suite passes, with nothing skipped, disabled or loosened to get
      there.
- [ ] Release preparation is done as the plan specified.

## If you run the inquiry FSM

MACSS defines this phase; it does not enforce it. If [inquiry](https://github.com/ccisnedev/inquiry)
is installed, it drives the same loop with enforced gates and a named sensor
stack — `iq fsm state --json` will tell you where you are and what it expects.
This skill is written to stand on its own without it.
