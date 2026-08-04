---
name: macss-specification
description: Take a request from arrival to Definition of Ready — publish it as an issue, turn it into a contract by evidence, and pass the gate.
---

## Goal

Take a business request and leave it ready to build: published as an issue,
carrying a contract that says what will be delivered, how it is accepted and
when — with every key decision licensed by evidence rather than by inference.

This is QA's job, and it ends at the Definition of Ready. One requirement is one
issue; if a request is too large to deliver as a unit, split **the request**
into smaller ones, each with its own issue and its own DoR.

## Method

**Decide by evidence, never by inference.** For every decision you are unsure
of, run a throwaway experiment: read the database, run code in a container,
probe the API. These validate a decision and are then discarded — they are not
product code.

**You hold the pen; the request is still his.** The Product Owner sends the
requirement by his own means — email, a meeting, a message — and does not sit
down to a form afterwards. So you fill `requisition.md`, with what he sent:
what problem this solves, who it affects, what happens if it is not done, and
how things work today versus how they should.

**Transcribe, never redact.** Put down what he said and nothing else. Do not
complete a gap, do not interpret what he meant, do not add scope. Everything the
request says must be traceable to a source you can name. When a section has no
answer, ask him and transcribe the reply — a request written by the person
interpreting it starts the analysis on a translation, and inferring what he
would have said is exactly that.

**The contract is yours.** `specification.md` is a lean business charter in the
domain's language — not an implementation document. Technical decisions belong
in the issue body, with a re-checkable handle.

## Steps

Every command that changes anything takes `--plan` or `--apply`; neither is a
default and a bare invocation is an error (ADR 0007). `--plan` writes a plan
file and touches nothing else. `--apply` shows the same plan and asks before
writing — and **you have no terminal to answer from**, so every `--apply` below
carries `--autoapprove`. Without it the command waits for an approval nobody is
there to give. Show the plan to the human and get their word before you pass it.

1. `macss requisition new <slug> --apply --autoapprove` (add `--lang es` for
   Spanish) — scaffolds `docs/requisitions/<YYYYMMDD>-<slug>/` with the form and
   its issue metadata, and records it as the **active requisition**, so later
   commands need no slug. Inputs and outputs are files on disk, not your memory.
2. Fill `requisition.md` with what the Product Owner sent, gathering from **all**
   the sources — email, meeting, chat. Transcribe; do not invent scope. Where he
   left a section unanswered, ask him rather than filling it in yourself.
   (`macss requisition export-template --apply --autoapprove` writes a blank
   form if you would rather send him one to fill directly.)
3. `macss requisition check` — verifies every section is answered. Fix exactly
   what it reports.
4. `macss requisition publish --plan`, show the plan to the human, then
   `macss requisition publish --apply --autoapprove` once they approve. This
   creates the GitHub issue carrying the request, and records its number.
   **From here the requirement has a consultable home**, and everything that
   follows is published on top of it.
5. `macss specification new --apply --autoapprove` — scaffolds the contract
   template into the same requisition, in the language the request was written
   in.
6. Fill `specification.md`: the committed delivery date, user stories each
   carrying at least one Given-When-Then acceptance criterion, an explicit scope
   that states what is **excluded**, the domain glossary and business rules, and
   the observable signal that will tell you it worked.
7. `macss specification check` — runs the gate. Fix exactly what it reports, one
   violation at a time, until it exits 0. Do not skip a violation.
8. `macss specification publish --plan`, then
   `macss specification publish --apply --autoapprove` once the human approves —
   updates the issue so its body reads request first, contract second.
9. `macss dor check` — the Definition of Ready. It composes the two checks and
   adds that the issue is published. When it exits 0, present the issue to the
   human for approval.

## On the observable signal

The request says what problem this solves. The contract must say **how we will
know it worked** — the signal you would look at afterwards, not an acceptance
criterion.

If the stated value cannot be turned into something observable, that is the
finding: the value was vapour, and the request needs rethinking rather than
specifying. No gate can judge prose; this translation is what catches it.

## Done when

- [ ] The request says what the Product Owner said, and every line of it can be
      traced to a source he gave.
- [ ] The issue is published and carries request plus contract.
- [ ] `macss dor check` exits 0.
- [ ] The issue is presented to the human for approval.

Once the DoR is met the issue body is **frozen**: a change of scope opens a new
requisition rather than an edit.
