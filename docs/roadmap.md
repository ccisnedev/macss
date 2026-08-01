# MACSS Roadmap

## Current Focus

The immediate focus of MACSS is to make the ecosystem boundary explicit and to
formalize the CLI as the official companion tool of the architecture.

This stage is about nomenclature, ecosystem structure, and command design.

Since 0.2.0 there is a second axis: MACSS is an architecture **and** an
engineering methodology, and the CLI now carries the lifecycle stages the
methodology defines. See **Stage 5 - Lifecycle Module Surface**.

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

## Stage 5 - Lifecycle Module Surface

MACSS is an architecture **and** an engineering methodology. The CLI has so far
expressed only the first half: `create` scaffolds the canonical structure, `api`
tools a subsystem. The methodology — how a change travels from a business
request to production — had no command surface here at all.

This stage adopts the **module-per-stage** direction, inherited from inquiry's
roadmap when the lifecycle moved to MACSS in 0.2.0. Inquiry adopted it in
2026-07 and narrowed it to the implementation stage in its 0.22.0; the stages it
handed over are planned here instead.

### Why a module per stage

Commands grouped by mechanism leak how the engine works: a user who wants to
"start analyzing" should not have to translate that into "run an FSM
transition". Naming the modules after the lifecycle stages makes the command
surface teach the methodology instead of hiding it.

Two principles carried over with the direction:

- **Every mechanical process is a command**, never an instruction that has a
  human or a model run `git` / `mkdir` / hand-write a scaffold.
- **Commands are not flow-aware**: they do their job and report it. They do not
  print a "next step" that would bias what the user does next.

### The stages and their modules

The lifecycle documented in the engineering handbook, with the module that
serves each stage:

| Stage | Module | Status |
|---|---|---|
| inception | `macss project` | planned — see below |
| requisition | `macss requisition` | planned |
| specification | `macss specification` | **shipped** (0.2.0) |
| issue | `macss issue` | **shipped** (0.2.0) |
| implementation | skills only, for now | **method** here (`macss-analyze/plan/execute`), **engine** in inquiry (`iq fsm`) |
| verification | `macss verification` | planned |
| deploy | `macss deploy` | planned — delegates to `macss-devops` (Stage 3.5) |

Shared verbs where they make sense: `start` (enter the stage), `check` (run the
stage gate), `skill` (show the stage's operating instruction). Every argument is
explicit and named — `--issue 40`, never a positional.

### The boundary with inquiry

MACSS is **in production**: it has to work on its own, for people who never
install anything else. Inquiry is a **scientific and engineering project** — a
state machine with enforced gates, free to evolve at its own pace. That
difference sets the boundary.

MACSS owns the **method** of the implementation stage and ships it as skills:
`analyze → plan → execute` is doctrine, documented in the engineering handbook,
and macss inherits it. Inquiry owns the **engine** that enforces it — the FSM,
the gates, the operators.

So the implementation stage appears in both, deliberately, and that is not a
fork: the skills are complete without any `iq` command, and they never restate a
gate rule, an event name or an artifact schema. **Doctrine can safely live in two
places; a contract cannot.** A macss user gets a working method; an inquiry user
gets the same method with gates that enforce it.

What would break this is building an `iq specification` module, or a
`macss fsm` — either one re-absorbs what the 0.2.0 / 0.22.0 split separated.
A `macss implementation` module that drives the method without an FSM is
compatible with it, and is left open.

### Inception: `create` becomes `macss project create`

`create` is the entry point to the whole methodology — a project has to exist
before anything can be requested of it — but it is a bare root-level command,
not a module. That is the one stage with no module name.

The resolution is **not** a new `init` module: the CLI grammar in
`architecture.md` reserves modules for nouns and verbs for leaf actions, and
`init` is a verb. Neither is an invented codename, which would make a core
surface unguessable for the sake of novelty. The stage's noun is already in the
vocabulary — **`project`** — and the three commands it needs are the same
concern at three moments:

```text
macss project create   # from nothing: scaffold the canonical structure
macss project check    # diagnose: what is missing, what is extra
macss project adopt    # retrofit: bring an existing project to the canon
```

`check` and `adopt` answer the question `create` cannot: *what if a project
already exists and should adopt MACSS?* Grouping all three under `project` also
puts the canon's verification next to its materialization, which is what keeps
`macss create` producing a project that satisfies
`code/book/src/project-structure.md`.

`macss create` stays as a deprecated alias for one minor version, since it is
the command every existing doc and install guide names.

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
