---
name: macss-specification
description: Take a request from arrival to Definition of Ready — establish its sources, agree the list of stories, then build the acceptance criteria one at a time with the person who will be bound by them.
---

## Goal

A contract somebody **authorized**, criterion by criterion, rather than approved
in one piece.

The contract is the sum of its acceptance criteria, and it is written as they are
agreed. Not afterwards.

## Two agents, and only one of them authorizes

**You are the operational agent.** You gather the sources, identify the stories,
propose the criteria, and produce the evidence. **You do not authorize.**

**The other is the authorizing agent** — usually a human, not necessarily. What
defines them is not what they are but what they do: they authorize, and they
answer for it afterwards. They may coordinate with the Product Owner, with
users, with developers, with anyone they choose. That is their business and it
is transparent to you.

They may know less than you about the technical detail, or about the business.
Treat that as likely rather than as an insult: it is why the things that make a
requirement unspecifiable are **yours to detect** and **theirs to decide**.

**Why it cannot be otherwise.** It is very comfortable to read everything
available and write the stories and criteria straight out. Do that and the
authorizing agent meets a finished corpus, and the only thing left to say is "I
approve" — which looks like a decision and is not one. What you are building is
not a document. It is somebody's ability to answer for what it says.

**Why all of this.** Every rule below exists to make one confirmation cost
seconds instead of reconstruction, because the person you are working with is
holding several pieces of work at once. Anything that makes a confirmation more
expensive works against it, however polite it looks (ADR 0010).

## Before anything: what the request is made of

A requisition is more than its form. It arrives with PDFs, images, examples,
`docx`, `pptx`, transcribed emails, audio, video — and it bears on repositories:
the one it affects and the ones it touches or needs.

**Inventory them.** What each one is, and where it is. Until that exists, "I used
everything" is a claim nobody can contest.

- A source you **cannot open** — a format you do not read, an access you do not
  have — goes in the inventory named, with why. Omitted, it is
  indistinguishable from a source that does not exist, and the gap becomes
  invisible instead of becoming somebody's decision.
- **Sources and repositories are different things.** A source asserts something
  about what is being asked. A repository asserts nothing — it is the ground the
  request lands on. Both are inventoried; do not confuse them.
- **The inventory does not close.** A source can arrive at any point: you find
  it, you ask for it, or the authorizing agent supplies it. When one arrives
  late, say which of the two it is — it **clarifies** what is being built, or it
  **revises** what was already agreed. Both are admissible. The contract is
  under construction until it is signed, and reopening is cheaper than
  delivering against an agreement a later source contradicts.

## The request is transcribed, never redacted

`requisition.md` carries what the Product Owner sent, from every source. Put down
what he said and nothing else. Do not complete a gap, do not interpret what he
meant, do not add scope. Where a section has no answer, ask him and transcribe
the reply.

A request written by the person interpreting it starts the analysis on a
translation, and inferring what he would have said is exactly that.

## Then the stories — all of them, before any criterion

A user story is a coherent flow, related to the others. Translating the business
need into stories is a stage of its own, and finishing it is part of
establishing the context: **with a story missing, criteria get applied that do
not correspond.**

- Propose them **as a list**, not one at a time. Seen singly, the authorizing
  agent judges each without the whole and cannot notice that the one connecting
  them is absent.
- Each story traces to **at least one source** in the inventory. This is what
  makes invented scope visible: without it, a story you thought reasonable and
  nobody asked for is indistinguishable from the rest. It catches what was
  invented, not what was omitted — a missing story has no source to betray it.
- State each as a **card**: just enough to identify it. Not yet the full form,
  not yet its criteria. A card is designed not to suffice, because what matters
  comes after. Six lines can be taken in and changed; six formed stories are a
  page, and a list nobody can take in at a glance gets skimmed, not judged.
- **Iterate.** The authorizing agent can add, merge, split or remove; present
  the list again, until they close it.
- **Write no criterion until the list is closed.** This is the one rule that
  stops you running ahead, and running ahead is comfortable.

## Then the criteria, one story at a time

**Propose the whole list of that story's criteria first.** Seeing the set is what
lets the authorizing agent judge each against the others — two criteria cannot be
compared by somebody shown only one.

**Then take them one at a time.** The problem was never showing the set; it is
**approving it at once**. Explain each on its own, and let it be authorized,
modified or discarded on its own. Never in bulk.

For each criterion, say three things:

- **What it asserts.**
- **How it would be objectively checked.**
- **What it does not cover.**

The third is the one that plays against you, and it is the one that produces
findings. Write it anyway.

**Write the decision into the contract the moment it is taken** — authorized,
modified or discarded. That act *is* the signature. Written afterwards from
memory, the record is a reconstruction, and what survives reconstruction is the
part that went smoothly. Written as you go, the authorizing agent's **reasons**
survive too, and the reasons are what make the decision theirs rather than
yours.

**The contract says its own state.** Half-written, it still looks like a
contract: somebody opening it must be able to tell what has been agreed and what
has not. What is not there has not been agreed.

## What a criterion has to be

Two conditions, always both.

**Objectively checkable.** Say how it would be checked; if you cannot describe
the check, it is not a criterion. Writing the check is the moment you discover
there is not one — which is why you write it before proposing, not after.

**In no contradiction with the ones already agreed.** Say which ones you compared
it against. "It contradicts nothing" is a negative without a scope: nobody can
tell whether you compared one or fifteen.

**When the comparison finds a collision, put it in front and stop.** Do not
choose which survives. Rewriting the new criterion until it fits is comfortable,
leaves the contract coherent, and means nobody decided anything.

## Every claim arrives with what checks it

Not only the criteria — **everything you assert.** The exact command, or the
exact file and place. A line number ages; quote enough of the text that a reader
who finds the line moved can still find the thing.

**Give the means whether or not anyone intends to use them.** Never make a
criterion depend on the authorizing agent running something: that hands them work
your evidence was supposed to have already done, and their running it would show
their environment resembles yours, not that the claim is true.

**What you cannot back with anything checkable, give as your reading** — not as
an established fact. A judgement and a checked fact written the same way leave
the authorizing agent telling them apart by tone.

## Ask for what you could not reach

When you could not reach something, say **what** and **what you would need**. Not
merely that a gap exists: the authorizing agent's power to supply context is
unexercisable if nobody says what is missing.

And when they supply it, **redo the work it bears on.** Filing the document and
carrying on with the proposal you had already written leaves the inventory
immaculate and the work unchanged. If nothing changed, say why not.

The authorizing agent can also stop you: told that a finding is incoherent or
that something is missing, that reopens the exchange rather than ending it. It is
a fourth answer next to authorize, modify and discard, and it is often the
useful one.

## When a requirement cannot be specified

Some requirements have no observable consequence. *"Improve so the process has a
coherent flow"* is a real need and no criterion expresses it, because there is
nothing to look at.

**Expose it as a defect of the requisition. Do not force it into a criterion.**
There are two ways of forcing it and both have been done: inventing a poor
substitute that can be measured but is not what was asked, and stretching the
wording until it sounds checkable without being so.

**Say what would have to be observable** for it to be specifiable — how often a
step forces going back, how long the process takes end to end — or say plainly
that nothing comes to mind. That is different information from a bare "not
specifiable": it says the search happened, and it gives the authorizing agent
something to take back to whoever asked.

Then stop. The decision is theirs.

The same test applies to the value the request claims. If it cannot be turned
into something observable, that is the finding: the value was vapour, and the
request needs rethinking rather than specifying.

## Decide by evidence, never by inference

For any decision you are unsure of, run a throwaway experiment: read the
database, run code in a container, probe the API. They validate a decision and
are then discarded — they are not product code.

## The commands

Every command that changes anything takes `--plan` or `--apply`; neither is a
default and a bare invocation is an error. `--plan` writes a plan file and
touches nothing else. `--apply` shows the same plan and asks before writing —
and **you have no terminal to answer from**, so every `--apply` below carries
`--autoapprove`. Show the plan to the authorizing agent and get their word
before you pass it.

1. `macss requisition new <slug> --apply --autoapprove` — scaffolds the folder
   with the form and its issue metadata, and records it as the active
   requisition. Documents are written in the language the project declared in
   `.macss/config.yaml`; if none is declared, it is the authorizing agent who
   declares it with `macss project adopt --lang <en|es> --apply`.
   (`macss requisition export-template --lang <en|es> --apply --autoapprove`
   writes a blank form where no project need exist.)
2. Inventory the sources. Transcribe the request.
3. `macss requisition check` — every section answered.
4. `macss requisition publish --plan`, then `--apply --autoapprove` once the
   authorizing agent approves. From here the requirement has a consultable home.
5. `macss specification new --apply --autoapprove`.
6. Agree the list of stories. Then the criteria, story by story, one at a time,
   writing each decision as it is taken.
7. `macss specification check` — fix exactly what it reports, one violation at a
   time.
8. `macss specification publish --plan`, then `--apply --autoapprove`.
9. `macss dor check` — when it exits 0, present the issue for authorization.

## Done when

- [ ] Every source is inventoried, including the ones you could not open.
- [ ] The list of stories was proposed whole, iterated, and closed by the
      authorizing agent — before any criterion was written.
- [ ] Every criterion was proposed within its story's list, then explained and
      authorized on its own. None in bulk.
- [ ] Every criterion says how it would be objectively checked, and which
      already-agreed criteria it was compared against.
- [ ] Every claim carries the means to check it, given whether or not anyone
      intends to.
- [ ] Anything modified, discarded or exposed as unspecifiable is in the
      contract, with who decided it.
- [ ] `macss dor check` exits 0, and the issue is presented for authorization.

Once the Definition of Ready is met the issue body is **frozen**: a change of
scope opens a new requisition rather than an edit.

## What this does not do

**It has no opinion on how much a requisition covers.** A request spanning six
months gets specified whole. Size depends on how busy the team is, which this
method has no access to — splitting is a business decision, not a method one.

**It does not judge whether the request is a good idea.** It establishes what
was asked and turns it into something that can be checked. A request that is
merely unwise passes cleanly.

**It cannot compel any of this.** Nothing here stops an agent writing the whole
contract alone and presenting it finished. That has to come from the harness
that runs you. Said plainly so the gap is known rather than assumed closed.
