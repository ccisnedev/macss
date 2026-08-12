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

1. Take the next phase from the plan on the issue. Work them in order; the
   order encodes the layer dependencies.
2. Write the test that proves the phase's acceptance criterion. Watch it fail.
3. Write the smallest code that makes it pass.
4. Run the full suite. Fix what broke — do not proceed on red.
5. Commit the phase.
6. Repeat until every phase is done, then do the release preparation the plan
   specifies: version bump, CHANGELOG entry, final commit.
7. Write the delivery, and publish it:
   `macss delivery new --apply --autoapprove`, then fill it — every acceptance
   criterion with somewhere a reader can look, what was deliberately not done,
   and how to reproduce it. Record `pr_title` in `state.yaml`: it is a commit
   message, so English and Conventional Commits whatever language the documents
   are in. Then `macss delivery check`, and
   `macss delivery publish --plan` before `--apply --autoapprove`.

   The pull request appears as the consequence. You do not open it: what you
   write is the document, and the document is what the person verifying reads.
   You are stating what you built; you are **not** saying it is correct. Nobody
   signs a delivery.

## Done when

- [ ] Every plan phase is implemented and committed.
- [ ] Every acceptance criterion is covered by at least one test.
- [ ] The full suite passes, with nothing skipped, disabled or loosened to get
      there.
- [ ] Release preparation is done as the plan specified.
- [ ] The delivery claims every criterion with its evidence, and is published.
