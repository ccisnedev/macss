# MACSS Roadmap

## Current Focus

The immediate focus of MACSS is to make the ecosystem boundary explicit and to
formalize the CLI as the official companion tool of the architecture.

This stage is about nomenclature, ecosystem structure, and command design.

Current operational context:

- `modular_api` has already achieved GraphQL integration.
- The complementary multi-SDK package ecosystem is already running through
	publish workflows.
- The remaining focus is to keep architecture docs and CLI contracts aligned
	with that delivered state.

## Stage 1 - Ecosystem Naming and CLI Boundary

### Goals

- declare MACSS as the ecosystem root
- declare `macss` as the official CLI entry point
- define the distinction between global commands and subsystem modules
- document that `modular_api` is a subsystem inside MACSS
- establish the future command-tree model for additional modules

### Status

- `macss` chosen as the official top-level CLI
- global root commands already exist
- documentation of ecosystem boundary now established

## Stage 1.5 - Subsystem Milestone Consolidation

### Goals

- record the delivery milestone of `modular_api` GraphQL integration
- record that package publication now exists across Dart, TypeScript, and
	Python surfaces
- codify CI/CD command ownership for GraphQL artifacts under
	`macss api graphql ...`

### Status

- milestone achieved in subsystem delivery
- documentation alignment in progress in the MACSS architecture repository

## Stage 2 - API Module Design

### Goals

- add a first-class `api` module to the CLI
- define the command grammar for API tooling
- keep API capabilities under `macss api ...` instead of creating a separate
	product CLI

### Design Direction

The first strong vertical slice of the `api` module is GraphQL tooling for
`modular_api`.

Planned direction:

- `macss api graphql compile`
- `macss api graphql check`
- `macss api graphql schema`

### Open Design Work

- decide the exact GraphQL subcommand set
- define required and optional flags
- define config discovery rules
- define output contracts and exit codes
- define CI/CD workflows

Additional alignment rule:

- CI/CD GraphQL compile workflows should be described and executed with
	`macss api graphql compile` as the canonical entrypoint.

## Stage 3 - Additional MACSS Modules

After `api`, MACSS is expected to grow additional modules as the ecosystem
expands.

Examples under consideration:

- `macss app ...`
- `macss db ...`
- `macss ai ...`

These are ecosystem modules, not separate top-level product CLIs.

## Stage 4 - Companion Tooling Expansion

MACSS is expected to grow as a development companion beyond basic command
dispatch.

Likely areas include:

- templates and project scaffolding
- prompts and future AI skills
- workflow automation
- future reference assets and book-related tooling

## Long-Term Direction

The repository is expected to remain the root of the architecture ecosystem.

That means the long-term shape of MACSS is larger than a library and larger than
the current CLI package. It is the place where the architecture, its tooling,
its automation, and its educational assets converge.

## Immediate Next Step

The next immediate step is to finalize the `api` module contracts after the
already achieved subsystem milestone, so implementation and documentation remain
synchronized.

The key decision already taken is this:

- the official command remains `macss`
- subsystem tooling lives under modules
- GraphQL compile mode for `modular_api` belongs under `macss api graphql ...`
