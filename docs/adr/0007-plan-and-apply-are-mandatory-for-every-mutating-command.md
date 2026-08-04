# 7. Plan and apply are mandatory for every mutating command

Date: 2026-08-04

## Status

Accepted. Supersedes the `--plan` / `--apply` convention as described in ADR
0004, which named a convention the code never implemented.

## Context

ADR 0004 closed with a sentence that has been quoted ever since: `adopt`
"previews by default, following the `--plan` / `--apply` convention `macss issue
publish` already uses."

No such convention was ever built. What shipped was a single flag, `--apply`,
with the absence of it standing in for the plan. Both implementations say so in
the same words:

```dart
/// `--plan` is the default, so it is not declared: passing `--apply` is the
/// deliberate act. A bare `adopt` previews and writes nothing.
```

So the convention had two names in the documents and one flag in the binary.
Every place that told a human what to type used the two-name version, and every
one of those commands rejects it:

```
❯ macss project adopt --plan
Error: unknown option --plan [VALIDATION_FAILED]
  parameter: plan
```

`macss project check` dictated that exact line as its closing advice. The
`macss-specification` skill dictated the same shape for `requisition publish`.
The book documented it for `adopt`. A test pinned the message, so the suite
defended the broken instruction rather than catching it.

The first instinct was to delete `--plan` from the documents and keep the
binary as it is. That is the cheaper repair and the wrong one, because the
documents were describing something the methodology actually wants and the
binary had quietly dropped:

- **A preview that vanishes is not a plan.** Today the preview is terminal
  output. It cannot be attached to an issue, diffed against a later run,
  reviewed by someone who was not at the keyboard, or kept as the record of what
  a change was expected to do. MACSS asks for exactly that kind of durable
  artifact everywhere else — the requisition, the contract, the ADR.
- **Absence is not a deliberate act.** The argument for not declaring `--plan`
  was that forgetting `--apply` should be safe. It makes the safe path the one
  you get by forgetting, which means the destructive path and the safe path are
  distinguished by an omission. Nothing in the invocation records which one the
  author meant.
- **`--apply` had no moment of consent.** It went straight from intent to
  writing. The plan existed only if you thought to run the command twice.

## Decision

**Every command that changes state MUST require an explicit `--plan` or
`--apply`. Neither is a default, and a bare invocation is an error.**

### Rules

1. **A mutating command with neither flag fails validation.** It exits non-zero
   and prints what the two flags do. It never falls back to previewing, because
   a fallback re-creates the omission this ADR removes.

2. **`--plan` computes the change and writes a plan file.** Nothing else is
   touched. The plan file is the artifact: a durable, readable report of what
   would happen, which can be attached, diffed, and reviewed away from the
   terminal.

3. **`--apply` computes the same plan, shows it inline, and asks for
   approval.** It writes no plan file — the operator is looking at it. Declining
   the prompt changes nothing and exits non-zero.

4. **`--apply --autoapprove` skips the prompt.** The changes are still printed,
   then applied. This is the invocation for agents, CI, and any context with no
   human at the keyboard.

5. **`--plan` and `--apply` are mutually exclusive.** Passing both fails
   validation rather than picking one.

6. **The plan a command shows under `--apply` is the plan it writes under
   `--plan`** — the same computation, rendered the same way. Two code paths
   would drift, and drift between plan and apply is the failure this convention
   exists to prevent.

7. **Read-only commands take neither flag.** A command that cannot change
   anything must not pretend to need consent.

### On `--autoapprove` rather than `--yes`

`--yes` answers a question without naming what is being agreed to; it reads as
dismissing a prompt. The flag is not about the prompt — it transfers the
approval itself from a human at the keyboard to whoever wrote the invocation.
`--autoapprove` says that. It also reads correctly in the place it will most
often be found, which is a script or an agent's skill file, where no one is
present to have said yes.

### The plan file

Plans are written to `.macss/plans/`, the local workspace this CLI already owns
and already git-ignores. A plan is a record of an intention, not of the
repository's history; committing plans would put a second, staler description of
every change beside the change itself.

### Applies to

Every command that writes to disk, to GitHub, or to the installed system:

| Module | Commands |
|---|---|
| `project` | `create`, `adopt` |
| `requisition` | `new`, `export-template`, `publish` |
| `specification` | `new`, `export-template`, `publish` |
| `skill` | `deploy`, `clean` |
| `api` | `graphql compile` |
| (global) | `upgrade`, `uninstall` |

And to no others. `doctor`, `version`, `help`, `skill list`, `project check`,
`requisition check`, `specification check` and `dor check` read and report.

## Consequences

**Every change gets a reviewable artifact before it happens.** `--plan` produces
something a second person can read. For `publish`, that is the issue body before
it reaches GitHub; for `adopt`, the file list before anything is created.

**The invocation records the author's intent.** Reading `--plan` or `--apply` in
a script, a skill, or a shell history tells you which was meant. Neither can be
arrived at by forgetting.

**Existing invocations break, and that is the point.** Every bare `macss
project adopt` and `macss requisition publish` that previews today will start
failing. The break is loud, immediate and says what to do, which is the only
honest way to remove a default that decided something the caller should have.

**Every agent-run skill must be updated to `--apply --autoapprove`.** A skill
that keeps a bare `--apply` will hang on a prompt with nobody there to answer.
This is the cost of rule 3, and it is paid once per skill.

**The documents that were already right stop being wrong.** `project check`,
the `macss-specification` skill and the book all dictate `--plan` today. They
were written against the convention ADR 0004 declared. They become accurate
without being edited — the binary catches up to them instead.

**The plan is written where the command was invoked, never into its target.**
This resolves what was left open here for `upgrade` and `uninstall`, and it
turned out not to be special to them. A plan written into the target would
itself be a change to the target, which is the one thing `--plan` promises not
to make; for `project create` the target is what the command would bring into
existence, and for `uninstall` it is what is about to be deleted. The invoking
directory is the only place that is none of those things.

## References

- ADR 0002 — explicit flags over positional args; rule 1 here is the same
  principle applied to consent
- ADR 0004 — where the `--plan` / `--apply` convention was first named
- `docs/requisitions/` — the requisition that surfaced the gap
