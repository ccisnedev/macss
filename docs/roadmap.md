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

## Stage 3.5 - Cross-Platform CLI and Project Flavors

### Cross-platform target

The `macss` CLI must operate natively on Windows, Linux, and macOS — the same
portability expectation Flutter sets. Project scaffolding (`macss create`) is
pure file generation and carries no external runtime dependency on any platform.

### Scaffolding flavors

`macss create` should let the developer choose the technology of each layer while
keeping the same architectural geometry (the wax foundation stays constant; only
the stamped implementation changes):

- **db**: `sqlserver` (DACPAC / `.dacpac` workflow) or `postgres` (declarative
	`pg_schema` workflow)
- **api**: `python`, `dart`, or `typescript` (aligned with the `modular_api` SDKs)
- **app**: Flutter as the initial base surface

Each flavor stamps a working base project that already follows the MACSS layer
model and request flow.

### Deploy and provision boundary

Deployment and provisioning are delegated to the published `macss-devops`
PowerShell module, not reimplemented in the CLI:

- `macss` (Dart) is the cross-platform front door; `macss-devops` remains the
	engine where PowerShell is the correct tool (SqlPackage/DACPAC, Docker stack
	over SSH, Flutter web publish).
- Delegation runs through `pwsh`, which is itself cross-platform (Windows, Linux,
	macOS), so a developer on any OS can deploy the same way.
- `pwsh` and the `macss-devops` module become documented prerequisites of the
	deploy/provision commands.

This keeps interface unification (one entry point) without implementation
rewrite, consistent with the separate-surfaces decision.

### `macss doctor` as dependency preflight

`macss doctor` owns the responsibility of failing early instead of mid-deploy.
It should detect missing tooling and print the exact install command for each
gap rather than a bare error:

- `pwsh` (PowerShell 7+), the `macss-devops` module, `.NET` runtime
- flavor-specific tools: `pgschema` (postgres), `microsoft.sqlpackage` / DACPAC
	(sqlserver), Docker, `ssh`, Flutter (app)

Each check reports present/missing and, when missing, the platform-appropriate
install command, so a developer on any OS can reach a deployable state from a
single diagnostic run.

## Stage 3.6 - DevOps Tooling Consolidation

### Ecosystem taxonomy

MACSS distinguishes two kinds of ecosystem members, and this decides where each
one lives:

- **Runtime products that user apps embed** — e.g. `modular_api` and its SDKs.
	These stay as sibling repositories, referenced (not vendored) by MACSS, because
	end-user applications depend on them at runtime and they have a life of their
	own.
- **Companion tooling for the MACSS workflow** — the `macss` CLI, documentation,
	book, templates, and DevOps automation. These live **inside** the macss repo,
	because no user app embeds them; they exist to serve the MACSS workflow.

### macss-devops migration

Under this taxonomy, `macss-devops` is companion tooling — the deploy/provision
engine the CLI delegates to — so it belongs in the macss repo at
`code/powershell`, alongside the CLI at `code/cli`.

- migrate `macss-devops` into `code/powershell` as a fresh English rewrite
	(git history not preserved; the module is early-stage)
- preserve the published module identity: same `macss-devops` name, same SemVer
	line, PSGallery publish workflow path-filtered to `code/powershell/**` for an
	independent release cadence within the monorepo
- co-location keeps the CLI ↔ devops delegation contract aligned atomically,
	removing the cross-repo version dance
- tracked in `ccisnedev/devops` issues #46 (legacy cmdlet removal) and #47
	(migration + rewrite)

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
