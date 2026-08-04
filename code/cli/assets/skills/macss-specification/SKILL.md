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

**The request is not yours to write.** `requisition.md` is a form the Product
Owner fills: what problem this solves, who it affects, what happens if it is not
done, and how things work today versus how they should. Do not fill it for him.
A request written by the person interpreting it starts the analysis on a
translation.

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
2. Hand `requisition.md` to the Product Owner and gather his answers from **all**
   the sources — email, meeting, chat. Capture exactly what was asked; do not
   invent scope.
   (`macss requisition export-template --apply --autoapprove` writes a blank
   form if you need one to send before opening a requisition.)
3. `macss requisition check` — verifies he answered every section. Fix exactly
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

- [ ] The Product Owner answered the request himself, from every source.
- [ ] The issue is published and carries request plus contract.
- [ ] `macss dor check` exits 0.
- [ ] The issue is presented to the human for approval.

Once the DoR is met the issue body is **frozen**: a change of scope opens a new
requisition rather than an edit.
