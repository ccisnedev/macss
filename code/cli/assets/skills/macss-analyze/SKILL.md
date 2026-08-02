---
name: macss-analyze
description: Run the analyze phase of a MACSS implementation cycle — build shared understanding of the problem and produce a diagnosis grounded in evidence.
---

## Goal

Shared understanding of the problem **before** any plan exists. Investigate,
build that understanding with the human, and produce a diagnosis that is the
sole input to planning.

Analyze is the first phase of the implementation stage, which begins once an
issue is specified and its acceptance criteria are agreed.

## Method

**Decide by evidence, not by inference.** Read repository state, existing
artifacts, project docs, and the tests or runtime behaviour that bear on the
problem *before* asking the human for missing facts. Ask only for what evidence
cannot recover: hidden constraints, human judgements, intent.

Every claim in the diagnosis carries a **re-checkable handle** — a `file:line`,
a URL, a command and its output. A claim nobody else can re-check is an opinion,
and opinions do not survive into a plan.

Analysis stops being interrogation once the problem is bounded. At that point it
becomes synthesis: say what the problem *is*, not what else you could ask.

## Steps

1. Read the issue: the request and the contract are both in its body. If
   `macss dor check` does not exit 0, you are in the wrong stage — the work is
   not ready to be analysed yet.
2. Map the affected MACSS layers, following the vertical
   `infra → db → api → app`. Name every layer the change touches and every
   module boundary it crosses.
3. Gather evidence for each affected area. Cite each finding with its handle.
4. Name the risks and dependencies: what could break, what must land first,
   what is uncertain.
5. Write the diagnosis: the problem, the evidence, the affected layers, the
   risks and the open questions.
6. Post it as a **comment on the issue** (`gh issue comment <n> --body-file`).
   That is where it belongs: the body is frozen at DoR and holds what was
   agreed, while the comments hold how the work unfolded. It is also why the
   diagnosis is not your memory — the next person, or the next session, reads
   it there.
7. Present it to the human and get agreement on the problem before planning.

## Done when

- [ ] The problem is stated in terms of the affected layers and modules.
- [ ] Every claim carries a re-checkable handle.
- [ ] Risks, dependencies and open questions are explicit.
- [ ] The diagnosis is posted on the issue, not held in the session.
- [ ] The human agrees this is the problem worth solving.
