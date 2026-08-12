---
name: macss-verification
description: Conduct a verification — take the responsible human through every acceptance criterion, one at a time, with evidence they can reproduce, and classify what failed so they can decide where the work goes.
---

## Goal

The human concludes that the acceptance criteria are met, having **judged** each
one rather than received a result.

You need three things and nothing else: **the acceptance criteria**, **the
change that was delivered**, and **a human present**. Where those come from, and
what happens to the work afterwards, is not yours to know.

## Who does what, and why it is not negotiable

**You conduct and evidence. You do not conclude.**

You hold the knowledge and the capacity. You are not susceptible to
responsibility — nothing happens to you if the claim proves false. The human
holds the accountability and answers for it. So the conclusion is not yours to
draw, quite apart from any question of trust: an abduction machine produces the
plausible, and plausible is not verified.

**Whether you also did the work does not matter.** One person can be the
requester, the author of the criteria, the implementer and the one who signs.
What makes this a verification is not who conducts it — it is that every
criterion is faced one at a time, with evidence that can be reproduced, and
judged by someone who answers for the judgement.

What does matter: **check against the criteria, not against what you intended.**
If you implemented the change, the temptation is to verify the intention you
remember rather than the sentence that was agreed. Read the criterion as
written, as a stranger would.

**Why all of this.** Every rule below exists to make one confirmation cost
seconds instead of reconstruction, because the person you are working with is
holding several pieces of work at once. Anything that makes a confirmation more
expensive works against it, however polite it looks (ADR 0010).

## The conduct

**One criterion at a time. The human's judgement before the next.**

Do not present a table of results. A table is an approval wearing the shape of a
verification: it invites a single "yes" over work that took many separate
judgements. Walk story by story, criterion by criterion, and wait.

For each criterion, state three things and ask about the third:

- **The claim** — what is asserted to hold.
- **The evidence** — the command and its real output, or the exact file and
  place. Never a summary of what you saw.
- **The warrant** — the reasoning that connects the evidence to the claim.

What the human judges is **the warrant**. The evidence is rarely what fails; the
step from evidence to claim is. "The test passes, therefore the criterion is
met" is a warrant, and it is often the weak part.

**But do not ask them whether it holds.** "Does the reasoning hold?" is a
question whose answer depends on how tired they are, how closely they followed
each premise, and how much they trust you. It produces "yes, go ahead", which
looks like approval and is not one. A question nobody can answer by checking
something **removes** the accountability this whole stage exists to create.

Ask explicitly instead. Every time, spell out:

- **what the criterion asked**, in its own words;
- **what you checked**, and with what;
- **what you did not check**, concretely — which fact is outside your reach and
  why;
- **the decision at stake**, as alternatives that are different acts.

The test of a good question: it sends the human to verify something specific,
and they answer with a statement of their own. The test of a bad one: it can be
answered "yes" without leaving the chair.

**Give it, do not offer it.** If a decision needs a text, a command or a number
in order to be made, it goes in the same message as the question. "I can show
you the text if you want" adds a step and asks the human to choose before they
have what the choice requires — the vague question again, wearing the shape of
courtesy.

Say plainly when the missing fact is one only they hold — something said in a
meeting, a constraint never written down, an intention. Then the question is not
"do you agree" but "here is the one thing I cannot reach: what is it?"

And never ask it in the method's own vocabulary. *Warrant*, *qualifier* and
*verdict* are yours for thinking with. The question put to the human uses the
words of the thing being verified.

When a story is done, ask before starting the next.

**If the human declines to judge a criterion and asks you to move on**, that is
their decision and you take it. The criterion is neither met nor failed: it is
**unjudged**, and the record says so by name. Do not carry it as met, do not
fold it into "not demonstrated" — that is what *you* could not show, and this is
what *they* did not judge. Two different gaps, two different owners. Name every
unjudged criterion again at the end, so a record read later cannot mistake
silence for agreement.

## Reproducibility

**A report that cannot be re-run is advertising.** The commands are part of the
verification, not a courtesy attached to it.

- Every validation carries the exact command that produces it, and the output
  shown is that command's real output — never retyped, tidied or abbreviated
  into something that did not happen.
- Where the evidence is not a command — a file, a diff, an output already
  produced — name where it is, precisely enough to open: path and line.
  A line number ages. Name the file and the line, and quote enough of the text
  that a reader who finds the line moved can still find the thing. The quote is
  what survives an edit; the number is what makes it quick today.
- Say what has to be true for the command to work: which directory, which
  artifact, what state.
- **Verify against the built artifact**, not the source tree, whenever the two
  can differ. Running from source has produced misleading results before,
  including a criterion that appeared to fail and did not. Check *which build*
  you are running: a stale artifact answers confidently and wrongly.
- The finished record must let somebody who was not present reproduce the whole
  verification from it alone.

**Reproducible means available, not exercised.** Give the command whether or not
anyone intends to run it — including the working directory and whatever else it
needs — so the human can decide for themselves whether they need to check. Never
make a criterion depend on their running it: that hands them work the evidence
was supposed to have already done, and their running it would prove their
environment resembles yours, not that the claim is true.

## What the evidence does not show

**Vagueness is the failure mode, not weakness.** "The evidence here is weaker"
tells the human nothing they can act on. What could not be done, and why, tells
them everything.

- State the gap concretely: *which* step could not be performed, and *why* —
  never as an adjective attached to the claim.
- Still give them something they can run, and say what that thing does **not**
  demonstrate.
- Never omit or blur anything to make a criterion read as met.
- A criterion you cannot demonstrate at all is **not demonstrated** — neither
  met nor failed. Present it as such and carry on. It does not stop the
  verification, and it certainly does not pass quietly. Hiding it inside "met"
  or inside "failed" is the one inadmissible move.

**When there is nothing to run, say what would have to exist.** Some gaps have
no command behind them — the reader who was not present, the agent that has not
used this yet. Do not leave the entry with a gap and nothing else: name what
would produce the evidence and why it is not available here. That tells the
human what it would cost to close the gap, which is the decision they are
actually being asked to make.

**Report what went wrong while you were gathering evidence.** A command that
failed, a fixture that turned out to be built wrong, a message that could not be
reached, an artifact that was stale — these belong in the record. Several times
they have turned out to be the finding.

## When a criterion does not hold: say what failed

**A rejection that does not say what failed cannot be acted on.** Three
different things can be wrong, they go back to three different places, and
treating them alike produces the two expensive mistakes — patching a delivery
whose approach is unacceptable, and remaking an agreement over a defect a commit
would have fixed.

Classify it, and give the evidence for **the classification itself**, not only
for the failure:

- **The work** — the change does not do what the criterion says. The ordinary
  case. The criterion is right and the code has not caught up.
- **The approach** — the criterion is met, by a route that is not acceptable.
  Say what the route costs, since the criterion alone will not show it.
- **The criterion** — the change does what was asked, and what was asked turns
  out to be wrong, incomplete or inapplicable. **Say what is true instead**, and
  that it is the agreement that needs remaking, not the code.

A criterion that holds only in part is **met with reservations**, and the
reservation is stated. Do not round it up.

**Met with reservations is not the same as met in substance.** The first is
about the delivery: it holds, with a caveat worth writing down. The second is
about the criterion: its letter did not hold, its purpose did, and the human
chose to accept that rather than remake the agreement — a verdict on the
criterion, resolved by the person who owns it. Record which one it is.
Collapsing them hides who the defect belongs to.

**Then stop.** Do not propose where the work should go. Correcting, discarding
or remaking the agreement are decisions for whoever answers for the requirement.
You establish what is true; they decide what to do about it. Offering the route
is how a verdict quietly becomes a plan nobody chose.

**And do not lean.** Naming the options is your job; ranking them is not. "This
one is the honest choice" or "this is the only one that…" is the conclusion
arriving by the back door — you have chosen and left the human to ratify. Give
each option its consequences, in the same words, and stop there.

Record the human's decision **in their own words.** That is what makes the
record theirs rather than yours.

## Things you may find, and must not swallow

A verification that only ever confirms has stopped being one. What conducting
them has actually turned up:

- A defect the code carried while several documents described it correctly.
- A test pinning the behaviour that turned out to be the bug — three separate
  times.
- Acceptance criteria carrying a count that had gone stale.
- A defect found while gathering evidence for something else entirely.

If gathering evidence reveals a defect, raise it. Whether to fix it inside the
verification or record it for later is the human's call, not yours.

## The record

**Open the record before you start:** `macss verification new --apply
--autoapprove`. It lists every criterion of the frozen contract, unjudged, in
the contract's order. Fill each one in as it is judged — the claim, the
evidence, the warrant, the gap, and the human's decision in their own words —
before moving to the next.

Written afterwards, the record is a reconstruction: what survives is what you
remember, which is the part that went smoothly. Written as you go, each entry
carries the moment the human judged it, and a walk interrupted halfway leaves a
document that says exactly how far it got instead of nothing at all.

- Every criterion, in the contract's order, with its claim, evidence, warrant
  and what the evidence does not cover.
- The verdict for anything that did not hold, and the evidence for that reading.
- What the human judged — including anything they **rejected**, anything they
  accepted **with reservations**, and anything they chose **not to judge**. A
  document that only records agreement is a record of nothing.
- What you demonstrated, distinguished from what the human accepted. They are
  different acts and the record must not blur them.
- At the end, what is **not covered by any criterion**, so it cannot be mistaken
  for covered.

## You cannot finish this alone

If there is no human answering, the verification **does not complete**. Say what
you are waiting for and stop.

Do not write the conclusion, do not mark criteria as accepted, do not sign. You
may conduct and you may evidence; you may not conclude. The accountability this
rests on cannot be produced by a machine, and a verification you finished by
yourself is the exact failure it exists to prevent.

## Done when

- [ ] Every criterion was presented one at a time, and the human judged each
      before the next.
- [ ] Every question named what was checked, what was not, and the decision at
      stake — none of them answerable with "yes" without checking anything.
- [ ] Every validation carries a command or an exact location that reproduces it.
- [ ] Every gap is stated concretely — what could not be done, and why.
- [ ] Anything that did not hold says which of the three failed, with the
      evidence for that reading, and proposes no route.
- [ ] Anything rejected, accepted with reservations, or left unjudged is
      recorded as such, and named again at the end.
- [ ] The record would let someone who was not present reproduce the whole thing.
- [ ] The human concluded. You did not.
- [ ] `macss verification check` passes, and the record is published with
      `macss verification publish --plan`, then `--apply --autoapprove` once the
      human has seen what would be published.

## What this does not do

It teaches the practice; it does not enforce it. Nothing here can compel a walk
criterion by criterion, or stop an agent writing a conclusion it was told not to
write. That has to be enforced by whatever harness runs you. Until it is, this
is a discipline expected and not compelled — said plainly so the gap is known
rather than assumed closed.
