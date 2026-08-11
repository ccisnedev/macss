# 10. Complete information back to the human is what makes accountability scale

Date: 2026-08-11

## Status

Accepted. Completes ADR 0005, which states the premise in one direction only,
and gives the rules of the `macss-verification` and `macss-specification`
methods the reason they were missing.

## Context

ADR 0005 is called *"Complete context for the agent, accountability for the
human"*. It settles the first half: the repository is written to be read by an
agent, so that one reading yields the whole. It does not settle the second half
— **what has to come back, and what for**.

Without that half, the accountability it names is an intention. The agent
investigates, decides a dozen things on the way, and presents a paragraph of
conclusions. The human reads the paragraph and types `ok`. The approval is real;
the understanding is not. That failure is recorded in roadmap Stage 6.5 as it
was observed, and the two methods built in response — #42 and #44 — each carry
rules aimed at it:

- ask explicitly: what the criterion asked, what was checked, what was **not**
  checked and why it is out of reach, and the decision at stake as alternatives
  that are different acts;
- give it, do not offer it — the text a decision needs travels with the question;
- every claim with the means to check it, available whether or not anyone
  intends to use them;
- do not lean: name the options and stop.

**Those rules were written without their reason.** Each states the failure it
prevents; none states what they are collectively for. A rule whose purpose is
missing is followed until it is inconvenient.

## Decision

**The information that flows back to the human is complete, explicit, and
carries its own means of verification — so that the human can hold several
pieces of work at once.**

That is the purpose, and it is a design choice that could have gone the other
way. The method could have optimized for one deep pass over one requirement at a
time. It does not. It optimizes for a human supervising several agents, and
every rule above exists to make a single confirmation cost seconds rather than
reconstruction.

### 1. The bottleneck is reconstruction, not attention

A human's capacity to supervise is not consumed by the number of decisions. It
is consumed by how much situation they must rebuild before each one. An agent
that hands over what the decision needs makes a confirmation cheap; an agent
that hands over a conclusion makes the human rebuild the case, and five of those
cannot run at once.

**This is why "complete and explicit" is not courtesy.** It is the mechanism.

### 2. Where the human's attention goes, and where it does not

Specification and verification are watched closely — they are where the human
authorizes and where they answer. **Implementation is delegated.** That is the
shape of the work, not a temporary state of trust.

Stated by the author of the canon on 2026-08-11:

> "El método me debe permitir paralelizar, por eso solo hago confirmaciones y por
> eso el método pide que se me dé la información completa… Es el equivalente a
> ser el jefe de un equipo de 5 desarrolladores junior: en esta etapa hay que
> estar muy pendiente de la especificación y la verificación; la implementación
> sí se delega."

### 3. It is a skill, and it is not automatic

Supervising several agents requires fast, deliberate context switching, and that
has to be trained. The method's part of the bargain is to make each switch as
cheap as it can be made. The human's part is to develop the capacity to make
them.

Recorded because it explains an asymmetry the method would otherwise seem to
impose arbitrarily: the agent is held to completeness the human is not.

## Consequences

**The rules of both methods now have a reason, and it is one reason.** Anything
that makes a confirmation more expensive works against this decision, however
polite it looks — an offer to show a text instead of the text, a question
answerable without checking anything, a gap named without what would close it.

**A new rule is testable against it.** "Does this make a confirmation cheaper or
more expensive?" is a question with an answer, where "is this good practice?" is
not.

**It bounds what may be delegated.** Implementation may. The two stages where
the human authorizes may not, and no amount of agent competence changes that —
ADR 0005 §4 and ADR 0008 §1 say why.

**It does not make the human's capacity unlimited.** Cheap is not free. Nothing
here claims a number of parallel pieces of work, and nothing measures when the
cost of switching exceeds the saving.

## References

- ADR 0005 — complete context for the agent; this completes its other half.
- ADR 0006 — autonomy is granted, not approved.
- ADR 0008 §1 — the answering is constituted by having written the document
  that decides.
- Roadmap Stage 6.5 — Accountability Engineering, where the failure is recorded
  as it was observed.
- Issues #42 and #44 — the two methods whose rules this decision explains.
