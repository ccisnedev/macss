# 5. Complete context for the agent, accountability for the human

Date: 2026-08-03

## Status

Accepted, with one part superseded. **Section 3's third row — "Human
verifies" — is replaced by ADR 0008.** Verification is performed by an agent
that did not implement; what the human does is write the `verification.md` that
decides, with an agent, and sign it. The correction is to *which activity*
carries the accountability §4 describes, not to §4 itself.

ADR 0008 also delivers the instrument this ADR's consequences deferred.

## Context

The shape of MACSS is documented. What is not documented is why it has that
shape.

A MACSS project is a monorepo holding every layer of the system — `code/infra`,
`code/db`, `code/api`, `code/app` — with `docs/` beside them rather than
elsewhere. ADR 0004 made that structure executable. ADR 0002 made every CLI
parameter explicit. ADR 0003 moved the lifecycle into MACSS and made each stage
publish its artifact on the issue. `docs/architecture.md` opens with the
ecosystem boundary and the CLI grammar.

Every one of those is a **consequence**. The premise they follow from appears in
exactly one place: `code/books/macss/src/es/ai-delivery-model.md` — twenty-seven
lines, in one edition of one book, under a heading a reader reaches on page
forty. No ADR records it. The architecture document does not state it.

The cost of leaving it unwritten is that the geometry reads as taste. Nothing in
the repository answers:

- Why does `docs/` live inside the project instead of a wiki or a docs site?
- Why do four layers that deploy independently share one repository?
- Why is the canon *verified* (`macss project check`) rather than merely
  documented?
- Why must every mechanical step be a command rather than an instruction?

Each has the same answer, and it is not "it is tidier."

A second gap compounds the first. **Two different things are called MACSS**: the
architecture a project instantiates, and this repository, the ecosystem root
that holds the CLI, the books and the automation. Both are described in the same
documents, and the reader is left to infer which one a given paragraph means.

## Decision

MACSS records its founding premise as an architectural decision, and states it
before the decisions that derive from it.

### 1. The unit of context is the repository

Every layer of the system and the documentation that governs it live in one
tree, so that one reading yields the whole: the schema behind an endpoint, the
client that calls it, the infrastructure it runs on, and the ADR that says why
any of them is shaped that way.

Split repositories give each human a partial view. They give an agent no view at
all — it cannot open what was never handed to it, and it cannot know that
something is missing.

### 2. The agent is a first-class citizen of that context

The repository is written **to be read by an agent**, not merely tolerated by
one. That is a design constraint with teeth, and the existing decisions are what
it produced:

| Decision | What the premise required |
|---|---|
| ADR 0002 — explicit flags | An interface that cannot be misread from its own text |
| ADR 0003 — the lifecycle is MACSS's | Each stage's reasoning published on the issue, not held in someone's head |
| ADR 0004 — the canon is executable | A structure that can be checked, not one that must be remembered |

The common thread: **machine-checkable and unambiguous are the same property.**
What an agent can verify, a new engineer can also read without oral history.

### 3. The division of labour

| Who | Does |
|---|---|
| Human | designs and specifies |
| Agent | implements |
| Human | verifies |

The human states the problem and the contract; the agent produces the solution;
the human decides whether it holds. Judgement stays where the context is
irreducible — what the business needs, what "correct" means here, what the
architecture should become.

### 4. Accountability does not delegate

Delegating implementation delegates **work, not responsibility**. The engineer
who specified the change and accepted the result answers for it, in exactly the
degree they would have answering for code they typed themselves. "The agent
wrote it" is not available as an explanation, which is the entire reason the
human verifies rather than merely receives.

This is why the gates verify artifacts rather than collect signatures: a
signature records that someone looked, a gate records what was checked. It is
also why review reports and a human decides.

### 5. The name covers two things, and documents must say which

- **The MACSS architecture** — the structure a project instantiates, produced by
  `macss project create` and verified by `macss project check`.
- **The MACSS repository** — this ecosystem root, holding the CLI, the books,
  the templates and the automation.

Both are MACSS. Prose that describes one must name which one.

## Consequences

**The premise becomes a test that proposals must pass.** A capability that
cannot be read out of the repository does not belong in the method. Anything the
agent must know goes in the tree — not in a wiki, not in a ticket comment, not
in the memory of whoever was on the call. This is the standard the existing
decisions already met; it is now stated, so the next one can be argued against
it.

**The premise is the argument for the monorepo, and it is also its bill.** A
full checkout is larger than a service repository, tooling must scope by path
(CI already filters on `code/cli/**`), and independently released components
need their own cadence inside one history — which is what Stage 3.6 of the
roadmap arranges for `macss-devops`. Those costs are accepted, not overlooked:
they buy the one property no split repository can offer.

**Not every ecosystem member follows it.** Runtime products that user
applications embed — `modular_api` and its SDKs — stay in sibling repositories,
because they have consumers of their own. The premise governs a *solution*'s
repository, not every artifact MACSS publishes. The roadmap's taxonomy already
draws that line; this ADR explains why the line falls there.

**Accountability has doctrine but no instrument yet.** Today's gates record
*what* was checked; none records *who* checked it. That instrument is
deliberately deferred: it belongs with `verification` and `dod`, which wait on
the environments of Stage 7. Until it exists, this ADR describes a discipline
the method expects and does not enforce — stated plainly here so the gap is a
known one rather than an assumed guarantee.

## References

- `code/books/macss/src/es/ai-delivery-model.md` — the premise's previous and
  only home; the chapter this ADR promotes
- `docs/architecture.md` — restructured to open from this premise
- ADR 0002, ADR 0003, ADR 0004 — the decisions that derive from it
- `docs/roadmap.md`, Stage 3.6 — the runtime-product / companion-tooling
  taxonomy; Stage 7 — the environments the accountability instrument waits on
