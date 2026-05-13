# 2. Explicit Flags Over Positional Arguments

Date: 2026-05-13

## Status

Accepted

## Context

The initial CLI spec defined commands using positional arguments (e.g. `macss create <path>`). This is a legacy pattern inherited from Unix tools designed for terse terminal use in the 1970s–90s.

Problems observed with positional arguments:

1. **Ambiguity at parse time** — The router (`cli_router`) must distinguish between route segments, positional args, and flags using heuristics. When no flags are present, positionals after the matched route are silently dropped (bug encountered with `macss create .`).
2. **Order dependence** — Positionals rely on position for semantics. Adding optional parameters later forces awkward conventions (sentinel values, fragile ordering).
3. **Poor discoverability** — A new user cannot tell what `macss create .` means without documentation. `macss create --path=.` is self-documenting.
4. **Hostile to scripting** — Positional args break when argument values resemble flags (e.g. a path starting with `-`). Flags with `=` or explicit values are unambiguous.
5. **Inconsistent extensibility** — As commands grow, mixing positionals and flags produces incoherent interfaces (e.g. `cmd <required-pos> --optional-flag`).

Modern CLIs (GitHub CLI, Fly.io, Railway, Vercel) use explicit flags for all semantic parameters and reserve positionals only for subcommand routing.

## Decision

All MACSS CLI commands MUST use explicit named flags for parameter input. Positional arguments (`req.positionals`) MUST NOT be used to pass user-supplied values.

### Rules

1. **Every user-supplied value is a flag** — with a long form (`--path`) and an optional single-char alias (`-p`).
2. **Positionals are reserved for command routing only** — the `cli_router` uses them to match `module subcommand` segments.
3. **Required flags must fail validation with a clear message** — including the flag name and usage example.
4. **Boolean flags use bare form** — `--force`, `--quiet` (no `=true` needed).
5. **Value flags use `=` or space** — both `--path=.` and `--path .` must work (handled by `cli_router`'s flag parser).
6. **No implicit defaults from position** — if a value is optional, it gets a documented default, not a positional fallback.

### Applies to

- All existing commands (`create`, `doctor`, `upgrade`, `uninstall`, `version`)
- All future commands and modules
- Both global and module-scoped commands

### Migration

| Command | Before | After |
|---------|--------|-------|
| create  | `macss create <path>` | `macss create --path=<dir>` (`-p`) |
| doctor  | (no positionals) | No change |
| upgrade | (no positionals) | No change |
| uninstall | (no positionals) | No change |
| version | (no positionals) | No change |

## Consequences

### Easier

- **Parsing is deterministic** — flags are unambiguous regardless of position or count.
- **Commands are self-documenting** — `--help` output with flag names is immediately useful.
- **Extensibility** — adding optional flags to any command requires no breaking changes.
- **Scripting and CI** — flag-based invocations are readable in shell scripts and YAML workflows.
- **Testing** — `CliRequest` can be constructed with explicit flag maps; no positional index bugs.

### Harder

- **Slightly more typing** — `--path=.` vs `.` (mitigated by short aliases like `-p`).
- **Spec documents need updating** — `cli_spec.md` section 4.2 still shows positional syntax.
- **Help text must be comprehensive** — each command must document its flags clearly since there's no implicit argument.

### Constraints on cli_router

- `req.positionals` is effectively deprecated for application use.
- If `cli_router` adds a `<param>` dynamic-segment feature in its route patterns, that remains a routing concern (e.g. `module <id> action`), not a substitute for flags.
