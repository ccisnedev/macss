# MACSS Architecture

## Purpose

This document states the premise MACSS is built on, and then the boundaries that
follow from it: the role of MACSS as an ecosystem root, and the role of the
`macss` CLI as the official companion tool of that ecosystem.

The order matters. The naming, the layer model and the command grammar are
consequences; read without the premise, they look like preference.

## Premise

**A MACSS project is one repository holding every layer of the system —
`code/infra`, `code/db`, `code/api`, `code/app` — with `docs/` beside them.**
One reading yields the whole: the schema behind an endpoint, the client that
calls it, the infrastructure it runs on, and the decision record that says why.

That completeness has a purpose. **The repository is written to be read by an
agent**, not merely tolerated by one. Split repositories give each human a
partial view; they give an agent no view at all, because it cannot open what was
never handed to it and cannot know that something is missing.

From that follows the delivery model:

| Who | Does |
|---|---|
| Human | designs and specifies |
| Agent | implements |
| Human | verifies |

And the constraint that governs it: **delegating implementation delegates work,
not responsibility.** The engineer who specified the change and accepted the
result answers for it. That is why the human verifies rather than merely
receives, and why the gates verify artifacts rather than collect signatures — a
signature records that someone looked, a gate records what was checked.

Most of this document is downstream of that premise. Explicit flags
(ADR 0002), an executable canon (ADR 0004) and a lifecycle whose every stage
publishes its reasoning on the issue (ADR 0003) are all the same requirement
applied at different altitudes: **machine-checkable and unambiguous are the same
property.**

The full statement, including what the premise costs and what it does not
govern, is ADR 0005.

## Two Things Named MACSS

Both appear in this document, and prose that describes one names which:

- **The MACSS architecture** — the structure a project instantiates, produced by
  `macss project create` and verified by `macss project check`.
- **The MACSS repository** — this ecosystem root, holding the CLI, the books,
  the templates and the automation.

The sections below are about the second.

## Product Boundary

MACSS is the parent architecture project.

It is not limited to a single SDK or runtime. It is the ecosystem root that may
contain multiple assets and companion surfaces, including:

- runtime-oriented components such as `modular_api`
- DevOps automation such as the published `macss-devops` PowerShell module
- architecture documentation
- CLI automation
- prompts and future AI skills
- future templates and reference assets
- book content under `code/books/<name>`

In this model, `modular_api` is a subsystem inside MACSS, not the umbrella
product itself.

## Milestone Update (June 2026)

The ecosystem reached an important execution milestone:

- `modular_api` completed GraphQL integration as a production subsystem
	capability.
- The complementary package ecosystem is active across Dart, TypeScript, and
	Python.
- Release automation for the package train is operating with publish workflows
	and validation gates.

This milestone validates the original boundary: MACSS as ecosystem root,
`modular_api` as a key subsystem component.

## Official CLI Boundary

The official command-line product is `macss`.

That decision means:

- the ecosystem has one official top-level CLI
- subsystem tooling is added as modules inside `macss`
- subsystem capabilities do not need their own top-level brand-first binaries

The CLI should be treated as an official development companion, not as a small
side utility.

## CLI Topology

The command tree is intentionally layered.

### Global Commands

Global commands apply to the ecosystem or workspace as a whole.

Examples:

- `macss doctor`
- `macss version`
- `macss upgrade`

These commands remain root-level because they are not owned by a single
subsystem module.

### Module Commands

Module commands are owned by a subsystem.

Planned examples:

- `macss api ...`
- `macss app ...`
- `macss db ...`
- `macss ai ...`

Each module can define its own nested surfaces and leaf actions.

### Subsurface Commands

Where a module has multiple distinct surfaces, the command tree should preserve
that boundary instead of collapsing everything into the module root.

For the API subsystem, the first planned surface is GraphQL.

Preferred shape:

- `macss api graphql compile`
- `macss api graphql check`
- `macss api graphql schema`

Avoid collapsing this into `macss api compile` unless the API subsystem is
proven to have only one meaningful build surface. At the moment, that would be
premature.

## Naming Principles

The naming contract for MACSS CLI should follow these rules.

1. Use `macss` as the only official top-level entry point, with `ma` as its
   short alias for the same binary.
2. Use nouns for modules and subsystem surfaces.
3. Use verbs only at leaf commands.
4. Keep global commands reserved for ecosystem-wide workflows.
5. Do not create new top-level product names when the capability is a subsystem.

This gives a consistent grammar:

`macss <module?> <surface?> <action>`

Examples:

- `macss project create --path=. --apply`
- `macss project check`
- `macss requisition new <slug> --apply`
- `macss requisition publish --apply`
- `macss specification check`
- `macss dor check`
- `macss skill deploy --apply`
- `macss api graphql compile --apply`
- `macss db migrate --apply` *(planned; the `db` module does not exist yet)*

Rule 3 is load-bearing, not cosmetic. When `create` needed a module of its own,
`init` was rejected for it — `init` is a verb, so it cannot name a module without
breaking the grammar. `project` is the noun the vocabulary already had, and it
groups the three commands that share one concern: `create` materializes the
canon, `check` verifies it, `adopt` retrofits it.

The modules split along the lifecycle MACSS defines
(`requisition → specification → issue → implementation → verification → deploy`)
and the subsystems it tools (`api`, `db`, `app`). See Stage 5 of the roadmap.

## Why `macss` Instead of `modular_api`

Using `modular_api` as the top-level CLI would incorrectly center one subsystem
as if it were the entire ecosystem.

That would become harder to defend as MACSS grows to include additional modules
such as `app`, `db`, `ai`, templates, and future automation.

Therefore the architectural boundary is:

- ecosystem root: `macss`
- API subsystem: `macss api`
- GraphQL build tooling: `macss api graphql ...`

For CI/CD, GraphQL compile workflows should be executed through
`macss api graphql ...`, not through a separate top-level `modular_api`
command surface.

## Current Implementation State

The CLI uses a modular structure internally and is being extended for API
surfaces.

- one root entry point in `bin/main.dart`
- one public runtime entry in `runMacss(...)`
- one global module already stabilized
- API GraphQL surface under active integration and hardening

That structure keeps subsystem growth compatible with the same CLI identity,
including CI/CD usage for GraphQL artifact workflows.

## Next Design Slice

The next strong design stage is hardening and completing the `api` module
surface.

Its first vertical slice is GraphQL artifact workflows for `modular_api`
compile mode, already validated as the priority integration path.

The next closure pass must define:

- subcommand tree
- configuration discovery
- input sources
- output directory contract
- validation behavior
- exit code contract
- CI/CD usage expectations

The key architectural point is already settled: this work belongs under
`macss api graphql`, not under a separate top-level CLI brand.
