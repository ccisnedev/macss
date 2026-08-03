# 6. Autonomy is granted, not approved

Date: 2026-08-03

## Status

Accepted

## Context

ADR 0005 established that delegating implementation delegates work, not responsibility,
and recorded honestly that accountability had doctrine but no instrument: today's gates
record *what* was checked, never *who* checked it.

Stage 8 makes the gap concrete. An agent runtime executes against real systems — it sends
messages to customers, moves records, runs operational tools. The question stops being
philosophical: **when an agent acts, who answers for it, and through what mechanism?**

The answer the field converged on during 2026 is per-act human review — *autonomy on
reads, human-in-the-loop on writes* — usually surfaced as an approval queue. It is a
reasonable default and it has a failure mode that is rarely named.

**Per-act review degrades into rubber-stamping.** A human approving two hundred actions a
day is not exercising judgment on any of them, but their signature lands on all of them.
That is worse than having no control, because it looks like control and it manufactures an
audit trail that cannot be defended. It also scales inversely to the value of an agent: the
more work the agent does, the less attention each approval gets.

There is a second cost. An agent whose every write waits for a human is not an agent that
works while nobody is watching — which is most of what an agent is for.

## Decision

**Accountability attaches to the grant, not to the act.**

The human decides, in advance and in writing, which capabilities the agent has and within
what bounds. The agent then executes freely inside that grant. Nobody approves individual
actions.

This is the model MACSS already runs on. Nobody approves each line an implementing agent
writes; a human specifies, and answers for having specified. It is also how a role works
for a person: you do not approve an employee's every act — you grant them a role, and you
answer for having granted it.

Six rules make it hold. They are not optional refinements; without them this is not the
grant model, it is the absence of one.

### 1. Nothing by default

A capability the agent can invoke is declared in its module's `policy.yaml` — in the
repository, in a diff, with a commit and an author. A tool that is not granted is not in
the agent's tool list at all; it cannot be called, not even wrongly.

This yields a canon-checkable invariant:

> **If `agent/modules/X/tools/` exists, `agent/modules/X/policy.yaml` must exist.**
> A tool without a declared policy is a capability nobody authorized.

### 2. Grants are bounded, not merely enumerated

Not "may use `refund`" but "may use `refund` up to N, on tickets assigned to it, at most M
per day, during working hours". The bound is part of the grant, enforced by the facade that
executes the tool.

This is what makes "let it execute everything it can execute" a safe sentence: it is safe
exactly insofar as **"can" is a small, deliberate set**. Broad grants give autonomy;
bounded grants give safety; they are the same mechanism, not opposing ones.

### 3. The axis is reversibility, not risk

The question is not "is this dangerous?" — a judgement that drifts with mood — but **"can
this be undone?"**, which is a property of the action.

- **Reversible** — grant generously. The cost of a mistake is a correction.
- **Irreversible** — grant with a compensating mechanism, or do not grant.

Stated plainly because it is easy to miss: **a message sent to a customer is
irreversible.** So is money moved and data deleted. Irreversible actions may still be
granted — but knowingly, and the compensation for an outbound message is measured response
quality, not an undo button that does not exist.

### 4. The audit is attributable, and it records the grant

Every action is recorded with: which agent, which role, which module, **which grant
authorized it**, which model, which prompt version, and the outcome. The CLI is the
chokepoint — the agent acts as an actor with identity, so the audit is a by-product of how
it works rather than a parallel system.

**This is the instrument ADR 0005 deferred, and it has a different shape than expected.**
The gate does not record who approved an act. It records **who signed the grant** — one
signature per capability instead of one per action, and the only one that can be defended
years later.

### 5. Evals are a deploy gate

If nobody reviews acts, what must be reviewed is aggregate behavior: before release
(evals, with a threshold that blocks) and after (outcome metrics).

In the review model the human *is* the eval. Remove the human from the act and the eval has
to exist for real.

**Review is not removed. It moves from the act to the release.**

### 6. Autonomy needs a stop

Rate limits, a circuit breaker on error rate, and a way to halt the agent immediately.
Autonomy without a stop is not autonomy; it is abandonment.

## Consequences

**Removing per-act review raises the bar on everything else, it does not lower it.** The
review model tolerates a vague grant because a human catches the act. The grant model has
no catcher. Every rule above is load-bearing, and adopting rule 1 without rules 4 and 5
produces an agent with authority and no accountability — the worst of the three positions.

**Policy may never live in the prompt.** A policy expressed in the system prompt is
negotiable with the prompt: an agent that can be asked to skip a check does not have that
check. Policy lives in the facade that executes the tool, where the agent's own reasoning
cannot reach it. This is why rule 1 names a file, not an instruction.

**Approval as a mechanism disappears; escalation replaces it.** The resulting map has three
outcomes and no waiting room:

| Situation | What happens |
|---|---|
| Not granted | The tool is absent. The agent escalates to a human — its own judgement, not a gate |
| Granted | It executes. It does not ask |
| Granted, bound exceeded | The facade refuses; the agent escalates. The bound is part of the grant, not an exception to it |

A human is still in the loop. They entered earlier, in writing, once per capability.

**A new capability becomes a pull request, not a configuration toggle.** That friction is
the decision, not a side effect of it. Someone must write the grant, bound it, and put
their name on it.

**This extends past agents.** Anything that executes on someone's behalf without asking
each time — a deployment pipeline, a scheduled job holding credentials, a script with
production access — is the same problem. The grant model is the general shape; agents are
the case that forced it to be written down.

**What it does not solve.** A correctly granted, correctly bounded, fully audited agent can
still do the wrong thing competently. The grant model makes that answerable, not
impossible. Rule 5 is the only defence against a bad grant, and it is a statistical one.

## References

- ADR 0005 — complete context and human accountability; this ADR supplies the instrument
  it deferred
- `docs/roadmap.md`, Stage 8 — `modular_agent`, where the module's `policy.yaml` lives
- `cacsi-dev/helper`, `docs/research/state_of_the_art_2026.md` §4 — the per-act review
  pattern this ADR declines, and the sources for it
