# 9. A default may derive, but never invent

Date: 2026-08-05

## Status

Accepted. Generalizes rule 1 of ADR 0007 from one convention to every option,
and supersedes the paragraph in ADR 0008 §3 that made English the default
language.

## Context

ADR 0007 removed a default from one place. `--plan` and `--apply` had been told
apart by an omission: forgetting the flag meant "do not write", so the safe path
and the writing path were distinguished by something nobody typed, and the
invocation recorded neither.

The same shape turned up again immediately, in a different option. `--lang`
defaulted to `en` and was passed per invocation, so `modular_cli_sdk` — an
English repository — had its first requisition opened in Spanish with nothing
objecting, and the CLI had no place to hold the answer. The fix there was a
single source of truth; the pattern underneath it was not local to language.

Stated as a principle: **a default is a silent action.** It saves a few
characters at the prompt and pays for them with an invocation that no longer
says what it does. Code should reveal its purpose, and so should the command
line that drove it — a shell history, a script, a skill file are all read later
by someone who was not there.

But "no defaults" written flat would break things this method built deliberately.
`--path` falls back to the current directory. `--slug` falls back to the active
requisition, which the roadmap presents as a feature: *"records it as the active
requisition, so later commands need no slug."* Neither of those is a silent
action, and a rule that forbade them would be obeyed by nobody.

## Decision

**A default may derive a value from context the caller has already established.
It may never invent a choice the caller never made.**

### The test

Ask what the default is reading from:

| The default reads | Verdict | Example |
|---|---|---|
| Where the caller is standing | Allowed | `--path` → the current directory |
| A pointer a previous command set and announced | Allowed | `--slug` → the active requisition |
| A value the project declared | Allowed | the language → `.macss/config.yaml` |
| Nothing — it picks | **Forbidden** | `--lang` → `en`; the absence of `--apply` → preview |

The first three answer *"the one you already named"*. The fourth answers *"one
of them"*, and which one is a decision the caller is entitled to make and was
not asked to.

### Consequences for what exists

- **`--lang` stops having a default.** On `requisition export-template`, the one
  command that runs where no project exists, it becomes **required** — that
  command cannot derive what it does not have. Everywhere else it is removed
  entirely, because the project declares the language once and every document
  derives it.
- **The command that writes `.macss/config.yaml` requires `--lang`.** Creating a
  project is exactly the moment the choice is made, so it is the moment it must
  be stated. `project create` and `project adopt` own that file, as they own
  everything about the canon.
- **ADR 0008 §3's "the default is English" no longer holds.** It was written
  before this principle was stated and reached the opposite conclusion by the
  reasonable-sounding route of picking a sensible fallback. A sensible fallback
  is still a choice nobody made.

### What this is not

It is not a rule against convenience. `--slug` defaulting to the active
requisition removes typing without removing information: the pointer was set by
a command the caller ran and saw. The distinction is whether the value was
*already established* or is being *supplied on the caller's behalf*.

Nor is it a rule about how much someone types. A required flag that repeats
what the project already declared would be noise, which is why the language is
derived rather than demanded on every command.

## Consequences

**Every declared `defaultValue` becomes a question with an answer.** The CLI has
several — `--engine`, `--source-root`, `--output`, `--path`, `--slug`, `--lang`.
Each must now be able to say which row of the table it sits in. Most derive from
the project's layout and stay; `--lang` does not and goes.

**The rule is checkable, eventually.** A parameter declaring a default could
declare what the default derives from, and a contract that cannot name its
source would fail at registration rather than at review. That instrument is not
built here — it is named so the gap is a known one, as ADR 0005 named its own.

**Invocations get longer and say more.** `macss project create --path=. --lang
en --apply` states four things, and a reader a year later needs no context to
know what it did. That is the trade, taken deliberately.

## References

- ADR 0007 — where the principle was first applied, to one convention
- ADR 0008 §3 — the language rule, whose "default is English" this supersedes
- `docs/roadmap.md` — the language section, and the active-requisition pointer
  that is the clearest legitimate default in the CLI
