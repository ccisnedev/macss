# Delivery

<!-- macss:lang=en · Language of this delivery. It follows the project, not the
     stage: the same language as the requisition and the contract it answers. -->

<!--
  This document is the **claim**, not the verdict. It is the mirror of the
  requisition: the request states what was asked and nobody signs it; the
  delivery states what was built and nobody signs it either. What is signed is
  the verification, by the person who answers for it.

  So write it for a reader who was not here — who holds the frozen contract and
  the diff, and nothing else. Everything they can derive from those two is
  already theirs. Only three things are not, and they are the three sections
  below.

  What does NOT belong here: what was built (the code says it), why it was
  built that way (an ADR says it, or nothing does), and how well it went. A
  delivery that argues its own quality is doing the verification's job, and
  doing it from the one position that cannot.
-->

## Metadata

| Field       | Value                                    |
| ----------- | ---------------------------------------- |
| Requisition | <!-- slug -->                            |
| Issue       | <!-- #N, the contract this answers -->    |
| Delivered   | {{DATE}}                                 |

## 1. Every criterion, and where its evidence is

<!-- One row per acceptance criterion in the contract, using the contract's own
     ids: the 3rd criterion of the 2nd story is US2-AC3. The gate checks that
     every one of them is here and that each names something a reader can run
     or open — a test name, a file and line, a command.

     This is a claim. You are saying "I believe this criterion is met, and here
     is where to look". The verifier checks it; you do not verify it here. A
     criterion you could not meet is not omitted — it goes in section 2. -->

| Criterion | Where the evidence is                              |
| --------- | -------------------------------------------------- |
| US1-AC1   | <!-- test name · file:line · command to run -->     |

## 2. What was not done, and why

<!-- The section the diff cannot show. An unimplemented criterion looks exactly
     like one implemented somewhere else, and a decision to leave something out
     looks like an oversight. Say it plainly, per item:

     - what is not there,
     - whether it was out of scope, deferred, or attempted and abandoned,
     - and what a reader should do about it.

     If everything in the contract was delivered, say "Nothing" — the empty
     section and the unwritten one are different statements, and only one of
     them can be trusted. -->

- <!-- what is missing, and why -->

## 3. How to reproduce it

<!-- What a verifier needs to get from a clean checkout to the evidence in
     section 1: the branch, and the command that runs the suite. Anything
     unusual that a reader would otherwise have to discover — a fixture to
     generate, a service to run, a flag to set. If there is nothing unusual,
     say so; "nothing unusual" is information. -->

- **Branch:** <!-- branch name -->
- **Suite:** <!-- the command that runs every test -->
- **Anything else:** <!-- setup a reader could not guess, or "nothing" -->
