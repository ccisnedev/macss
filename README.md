# MACSS

Modular Architecture for Comprehensive Software Solutions.

This repository is the root of the MACSS architecture ecosystem. It is not a
single runtime library. It is the parent project that organizes the
architecture, documentation, companion tooling, prompts, templates, and future
automation assets around the ecosystem.

## What Lives Under MACSS

MACSS is the umbrella project for multiple development surfaces.

- Architecture documentation and ecosystem conventions
- The official `macss` companion CLI
- Project scaffolding and templates
- Reference content such as the book under `code/book`
- Future AI skills and companion automation
- Ecosystem components such as `modular_api` and `macss-devops`

These components are the root product's building blocks, but none of them is the
root product. The root product is MACSS itself.

## Ecosystem Components

MACSS is the ecosystem root. The components below are independent, already
published, and live in sibling repositories. MACSS references them; it does not
vendor them.

### `modular_api` — runtime and SDKs

Monorepo of official SDKs for building modular, use-case-centric HTTP APIs, with
aligned implementations in Dart, TypeScript, and Python. Each endpoint maps to
one use case. Optional capabilities — health, metrics, OpenAPI, interactive
docs, and GraphQL — are official plugins mounted under a shared `basePath`.
GraphQL provides the optional CQRS query side; REST-only APIs remain first-class.

| Language | Package | Registry |
|---|---|---|
| Dart | `modular_api` | pub.dev |
| TypeScript | `@macss/modular-api` | npm |
| Python | `macss-modular-api` | PyPI |

The `macss api graphql ...` CLI surface operates on `modular_api` projects.

### `macss-devops` — PowerShell automation

Published PowerShell module for DevOps automation across development, testing,
CI/CD, and deployment: Flutter builds, declarative SQL Server packaging, Docker
stack deploys over SSH, GitHub issue creation, and `dev → main` merges, among
others.

```powershell
Install-Module macss-devops -Repository PSGallery -Scope CurrentUser
Import-Module macss-devops
Get-Command -Module macss-devops   # list available cmdlets
```

## Milestone Achieved (June 2026)

The `modular_api` subsystem has reached a major delivery milestone inside the
MACSS ecosystem:

- GraphQL integration is now implemented across the subsystem.
- The multi-SDK package ecosystem (Dart, TypeScript, Python) is already
	operational and publishable.
- Complementary publish workflows and release gates are in place for the
	package train.

This confirms the intended architecture boundary:

- `modular_api` provides runtime and package surfaces.
- `macss` provides the companion CLI boundary used by teams and pipelines.

## CLI Naming Decision

The official command-line entry point for the ecosystem is `macss`.

This means MACSS does not expose a separate primary CLI named
`modular_api`, `modular-api`, `modularapi`, `mapi`, or `ma`.

The naming model is:

- `macss` is the official ecosystem CLI
- global commands live directly under `macss`
- component-specific tooling lives under modules such as `macss api`

Examples:

```text
macss create --path=.
macss doctor
macss version
macss api graphql compile
```

Short aliases such as `ma` may exist later as convenience wrappers, but they
are not the official documented contract.

## CLI Scope

The `macss` CLI is the official companion tool of the ecosystem.

Its purpose is broader than simple project creation. Over time it is expected
to become the development companion for architecture-aware workflows such as:

- project creation and workspace bootstrapping
- environment diagnostics and upgrade flows
- API build and validation tooling
- database-oriented automation
- future AI skills, prompts, and development assistance
- future project templates and guided generation flows

The CLI already supports global commands. For example:

```text
macss create --path=.
```

That command remains intentionally global because it operates at the workspace
or project-root level rather than inside a subsystem module.

## Command Model

MACSS uses a modular command tree.

- Global commands are root-level workflows with ecosystem-wide meaning.
- Modules group commands for a specific subsystem.
- Submodules may exist where a subsystem has multiple surfaces.
- Verbs should appear at the leaves of the command tree.

Current direction:

- global: `create`, `doctor`, `upgrade`, `uninstall`, `version`
- planned modules: `api`, `app`, `db`, `ai`
- future companion areas: templates, prompts, skills, and book-related tooling

## `modular_api` Inside MACSS

The first major subsystem expected to grow under the CLI is `api`.

`modular_api` tooling should be exposed through `macss api ...`, not through a
separate top-level product CLI.

For GraphQL compile mode, the current direction is:

```text
macss api graphql compile
```

In CI/CD, GraphQL artifact compilation must be executed through the `macss`
companion CLI surface, preserving one ecosystem entry point and avoiding
tooling drift.

This keeps the command aligned with the actual product structure:

- MACSS is the ecosystem root
- `api` is the subsystem
- `graphql` is the surface within the API subsystem
- `compile` is the action

## Why This Model

This naming and command structure is intentional.

- It keeps a single official entry point for the ecosystem.
- It avoids fragmenting tooling across unrelated top-level binaries.
- It matches the product boundary: MACSS is the root, `modular_api` is a component.
- It gives the CLI room to grow into a stronger development companion.
- It preserves clear separation between global workflows and subsystem workflows.

## Repository Direction

The MACSS repository is expected to grow as an ecosystem root, not only as a
CLI package. Its `code/` tree may include multiple companion surfaces over
time, including documentation assets, templates, automation, and future book
content.

At this stage, the immediate focus is naming, ecosystem boundaries, and CLI
structure.

## Next Design Step

The next strong design stage in the CLI is hardening the `api` module after the
GraphQL and package-ecosystem milestone.

The first concrete vertical slice under that module is expected to be GraphQL
artifact tooling for `modular_api`, beginning with commands in the shape of:

```text
macss api graphql compile
macss api graphql check
macss api graphql schema
```

The exact contracts of `check` and `schema`, plus CI/CD operating profiles,
should be finalized as the next slice of the `api` module architecture.
