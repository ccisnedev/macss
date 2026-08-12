# 8. The delivery cycle is symmetric, and the signature goes on the second document

Date: 2026-08-05

## Status

Accepted, with one paragraph superseded. It supersedes section 3 of ADR 0005,
which assigned verification to the human, and delivers the accountability
instrument ADR 0005 deferred.

**§3's "the default is English" is superseded by ADR 0009**, which holds that a
default may derive a value the caller already established but may never invent
one. The language rule itself — one language per project, declared once — stands
unchanged.

## Context

ADR 0005 recorded the division of labour as three rows:

| Who | Does |
|---|---|
| Human | designs and specifies |
| Agent | implements |
| Human | verifies |

and closed with an admission: *"Accountability has doctrine but no instrument
yet. Today's gates record what was checked; none records who checked it. That
instrument is deliberately deferred: it belongs with `verification` and `dod`."*

ADR 0006 then established that **accountability attaches to the grant, not to
the act**, and named the failure mode that makes per-act approval worthless:
*"A human approving two hundred actions a day is not exercising judgment on any
of them, but their signature lands on all of them… it looks like control and it
manufactures an audit trail that cannot be defended."*

Two things have changed since.

**The issue side of the lifecycle is finished and the pull-request side is
not.** `requisition.md` publishes the issue, `specification.md` appends the
contract, `macss dor check` composes both gates and freezes the body. Nothing
answers to any of that after the code is written: `macss-execute` produces a
pull request as a side effect, with no document behind it, and `verification`
and `dod` exist only as planned modules in the roadmap.

**"The human verifies" was never true, and could not be.** A person reading a
diff to confirm that every acceptance criterion holds is doing work an agent
does better and more reproducibly — the same argument the roadmap already makes
for review: *"A human review is not reproducible: two reviewers, or the same
reviewer twice, apply different standards to the same diff."* Keeping
verification in human hands on capability grounds contradicts the premise of
the whole method.

What a person cannot delegate is not the judgement. It is answering for the
result. Those are different things, and ADR 0005 §4 already said so — *"The
agent wrote it is not available as an explanation"* — while ADR 0005 §3 assigned
the wrong activity to protect it.

## Decision

**The lifecycle is two symmetric pairs, and the human signs the second document
of each pair.**

| Issue side | Authored by | Pull-request side | Authored by |
|---|---|---|---|
| `requisition.md` + `issue.yaml` | the Product Owner, transcribed | `delivery.md` + `pr.yaml` | the implementing agent |
| `specification.md` | **human with agent** | `verification.md` | **human with agent** |
| `macss dor check` | | `macss dod check` | |

### 1. The first document of each pair reports; the second commits

`requisition.md` states what was asked. `delivery.md` states what was built.
Neither is the human's to sign: one belongs to whoever made the request, the
other to whoever wrote the code.

`specification.md` states what we commit to build and how it will be accepted.
`verification.md` states that it was, and shows why. **These two carry the
signature**, and they are the two the human writes *with* an agent rather than
receives from one.

That is the instrument ADR 0005 deferred. Accountability is not recorded by a
field naming a person; it is constituted by the fact that a person wrote the
document that decides.

### 2. Participation, not approval

The human does not review a `specification.md` an agent drafted and say yes,
and does not review a `verification.md` an agent drafted and say yes. They
write them, iterating, with the agent. The distinction is the whole of ADR
0006: approving a document you did not shape is the rubber stamp, arriving by a
different door.

### 3. The language belongs to the project, not to the artifact

All four documents are written in **one** language, and which one is a property
of the project rather than of any document's position in the cycle. A project
whose Product Owner writes Spanish has a Spanish requisition, and a Spanish
verification with it; a project written in English has all four in English.

Drawing the boundary between the issue and the pull request was considered and
is wrong. It would leave one requirement described in two languages, split at
the point where a reader most needs to follow the thread — from the criterion
that was agreed to the evidence that it holds.

This is a rule about the **artifacts**. It does not touch the one the roadmap
already states for the design: directory names, slugs, code, comments and commit
messages are English in every project, whatever language its documents are in.

**The project says it once, in `.macss/config.yaml`.** Every command that opens
a document reads the language from there and none of them takes `--lang`. A
setting passed per invocation is a setting that can differ per invocation, and a
project that can answer "what language is this?" differently on Tuesday does not
have an answer. This file is **versioned**, so the answer is the same for
everyone who clones the repository rather than a property of one machine.

**There is no default.** This paragraph once said English was, on the reasonable
argument that a project which never chose should come out consistent with the
method. ADR 0009 supersedes it: a sensible fallback is still a choice nobody
made. The command that writes `.macss/config.yaml` requires `--lang`, because
creating a project is the moment the choice is made and therefore the moment it
must be stated.

There is exactly one exception, and it is not a weakening. `export-requisition`
writes a blank form at a path that **need not be a MACSS project at all** — there
is no config to read, because there is no project. It takes `--lang`, and it is
the only command that does.

That is also the only export worth having. Of the four documents, the requisition
is the one handed to somebody outside the team: the Product Owner fills it, or it
is transcribed from what he sent. The other three never leave. `requisition.md`
is, in effect, this method's issue template — and a template for a contract, a
delivery or a verification would be a form for work nobody outside is doing.

### 4. There is no `macss pr` module

For the reason there is no `macss issue` module. The roadmap states it for the
issue: *"the issue is a consequence of publishing the requisition, not a
separate artifact someone composes."* The same holds here — the pull request is
a consequence of publishing the delivery.

### 5. The modules mirror the ones that exist

```text
macss delivery      new / check / publish             → opens the pull request
macss verification  new / check / publish             → appends to its body
macss dod check                                       → composes both, and review
```

Same verbs, same convention (ADR 0007), same shape: `new` opens the artifact,
`check` runs the stage gate, `publish` materializes it on GitHub.

**Shipped, and two things were learned in the building.** `delivery publish`
pushes before it opens the pull request, because `gh pr create` resolves the
head on the remote — which makes it the first command here that writes outside
the machine by a route that is not `gh`, and the first whose `--plan` names
something other than a file. And the two stage gates read the contract from
different places on purpose: `delivery check` from disk, where the implementer
is and the file is there by construction, and `verification check` from the
published issue, because the verifier may hold no copy at all.

### 6. `dod check` starts at its floor, and the floor is not arbitrary

The minimum meaningful gate is **every acceptance criterion declared in
`specification.md` is named in `verification.md`, and each carries a pointer to
its evidence** — a test name, a command, a file and line.

This rule is not new. It lived in the specification gate as
`_checkAcTraceability`, generating `US<n>-AC<m>` ids and requiring each to be
traced, and was removed in 0.4.0 for a stated reason:

> Under one requirement, one issue they are **tautologies** — the document *is*
> the issue, and every AC in it is covered by definition.

That reasoning was correct and it does not reach across the pair.
`verification.md` is a different document from `specification.md`, so tracing
every AC into it is a real check again. The symmetry restores the rule to the
place where it means something.

**The gate checks coverage and shape, never truth.** It cannot tell whether the
evidence is honest — exactly as `requisition check` "judges presence, not
quality". What catches a false claim is the person who wrote the document, and
that is not a weakness of the gate: it is where the signature was placed on
purpose.

### 7. Who executes each stage

| Stage | Executed by |
|---|---|
| requisition | analyst with an agent, transcribing the request |
| specification | **human with an agent** |
| definition of ready | automated — `macss dor check` |
| implementation | an agent: analyze, plan, execute under TDD |
| ci + review | automated — the platform's runner and a reviewing agent |
| verification | **human with an agent** |
| definition of done | automated — `macss dod check` |
| merge | the human, confirming the grant was honoured |

**The verifying agent may be the implementing one.** This section first said it
must not be, on the argument that an agent checking its own work confirms its
own assumptions. `macss-verification` — written after this ADR and shipped in
0.8.0 — reaches the opposite conclusion and is right:

> Whether you also did the work does not matter. One person can be the
> requester, the author of the criteria, the implementer and the one who signs.
> What makes this a verification is not who conducts it — it is that every
> criterion is faced one at a time, with evidence that can be reproduced, and
> judged by someone who answers for the judgement.

The worry the rule protected against is real and survives, better placed:
*"check against the criteria, not against what you intended. If you implemented
the change, the temptation is to verify the intention you remember rather than
the sentence that was agreed."*

What guarantees the outside reading is not **who** conducts the walk but **where
it starts** — the frozen contract and the diff, which is what this section
already said. `macss verification new` makes that mechanical: it reads the
contract off the published issue rather than off the working tree, so the walk
begins from what was agreed and not from what anybody remembers agreeing.

### 8. The merge asks about conformance, not quality

By ADR 0006, the accountable act is the grant — here, signing the
specification. The merge then asks whether the delivery stayed inside what was
granted, which `verification.md` is written to answer in the body of the pull
request itself.

A human who wants to check out the branch and confirm it personally always may,
and sometimes should. What must not happen is the merge becoming the place
where accountability is manufactured rather than confirmed.

## Consequences

**`macss-execute` stops creating the pull request.** It writes `delivery.md`
and `pr.yaml` and publishes them; the pull request appears as the consequence.
The roadmap's description of the execute phase — *"the code, under TDD, and the
PR"* — changes with it.

**A `macss-verification` skill is needed, and it is the twin of
`macss-specification`.** Both are the human-with-agent document skills; they
sit at the same position on their respective sides. This is one new skill, not
an adaptation of the existing four: the other three (`analyze`, `plan`,
`execute`) keep their shape, and only `execute` changes what it hands over.

**The pull-request body freezes at DoD**, as the issue body freezes at DoR. A
change after that opens new work rather than editing the record of what was
delivered.

**`dod check` cannot be composed entirely from files on disk.** Every other
gate reads the working tree; this one must also know that review passed, and
review *"fires on the PR"* on the platform. That dependency is the hard part of
the stage and is deliberately out of the floor described in §5 — the first
`dod check` composes the delivery gate, the verification gate, and a published
pull request. Review joins it when the platform integration exists.

**`.macss/` stops being entirely machine-local.** It has held only the active
pointer and, since ADR 0007, the plan files — all of it reproducible, none of it
worth committing. `config.yaml` is the first thing in there that must travel with
the repository, because a project's language is not a property of one developer's
checkout. Anything that git-ignores the workspace wholesale has to except it.

**`--lang` disappears from every command except one.** It is removed from
`requisition new` and `specification new`, which read the config instead, and
survives only on `export-requisition`, which by definition runs where no config
exists. `specification export-template` is removed outright: the requisition is
the only document that leaves the team, so it is the only one worth exporting.
Both are breaking changes to a shipped CLI.

**The rule that produced this was found by breaking it.** The first requisition
opened in `modular_cli_sdk` — an English repository — was opened with `--lang es`,
against the command's own default, and nothing objected. That is what a setting
with no single source of truth costs.

**`dod check` has to be a gate, not a habit, and there is already evidence.**
The first pull request delivered under this ADR — `modular_cli_sdk#14` — was
verified and merged **without a `verification.md`**. Not by disagreement: the
author intended to write one and forgot. That is the ordinary outcome, and ADR
0006 already names the rule it breaks — *"prefer absence over refusal, refusal
over instruction, and never instruction alone."* "Remember to write the
verification" is an instruction. What makes it hold is a gate that does not pass
without it, and until `macss dod check` exists this ADR describes a discipline
the method expects and cannot enforce — the same honest gap ADR 0005 recorded
about accountability, one level down.

**ADR 0005's table gains a row and loses one.** "Human verifies" becomes
"agent verifies, human writes the verification and signs it". The
three-row division of labour was too coarse to hold the difference between
doing the work and answering for it.

## References

- ADR 0005 — the founding premise, its division of labour, and the deferred
  instrument this ADR delivers
- ADR 0006 — accountability attaches to the grant; the rubber-stamp failure
  mode this design is shaped to avoid
- ADR 0007 — the `--plan` / `--apply` convention the new modules follow
- `docs/roadmap.md` — the lifecycle table where `verification` and `dod` were
  reserved, and the argument that review is a gate outside implementation
- `code/cli/lib/modules/specification/specification_gate.dart` — the AC-tracing
  rule removed in 0.4.0, recoverable from commit `6688702`
