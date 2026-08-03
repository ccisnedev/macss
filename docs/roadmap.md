# MACSS Roadmap

## Current Focus

The immediate focus of MACSS is to make the ecosystem boundary explicit and to
formalize the CLI as the official companion tool of the architecture.

This stage is about nomenclature, ecosystem structure, and command design.

Since 0.2.0 there is a second axis: MACSS is an architecture **and** an
engineering methodology, and the CLI now carries the lifecycle stages the
methodology defines. See **Stage 5 - Lifecycle Module Surface**.

A third axis follows from the second: a methodology has to be teachable, not
only executable. See **Stage 6 - The Written Record**.

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
portability expectation Flutter sets. Project scaffolding (`macss project create`) is
pure file generation and carries no external runtime dependency on any platform.

### Scaffolding flavors

`macss project create` should let the developer choose the technology of each layer while
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
- reference assets and book-related tooling — see **Stage 6**

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
| inception | `macss project` | **shipped** (0.3.0) — `create` / `check` |
| requisition | `macss requisition` | **shipped** (0.4.0) — the PO's form, published as the issue |
| specification | `macss specification` | **shipped** (0.4.0) — the contract, appended to that same issue |
| definition of ready | `macss dor` | **shipped** (0.4.0) — composes both gates plus "the issue exists" |
| implementation | skills, for now | `macss-analyze` / `macss-plan` / `macss-execute` — **shipped** (0.5.0); `macss-review` planned, see below |
| verification | `macss verification` | planned |
| deploy | `macss deploy` | planned — delegates to `macss-devops` (Stage 3.5) |

There is no `macss issue` module. One requirement is one issue, and the issue is
a **consequence** of publishing the requisition, not a separate artifact someone
composes: `requisition publish` creates it, `specification publish` appends the
contract to it, and at DoR the body freezes. A module for it would imply the
issue could be authored independently of the request it carries.

Shared verbs where they make sense: `new` (open the artifact), `check` (run the
stage gate), `publish` (materialize it on GitHub, `--plan` then `--apply`).
Every argument is explicit and named — `--issue 40`, never a positional.

### Implementation is four phases, not three

Implementation is the one stage MACSS serves with skills rather than commands,
because what it needs is judgement rather than mechanism. Three of its phases
ship today; the fourth is the gap.

| Phase | Skill | Produces |
|---|---|---|
| analyze | `macss-analyze` | the diagnosis, as a comment on the issue |
| plan | `macss-plan` | staged work, each stage with an executable verification |
| execute | `macss-execute` | the code, under TDD, and the PR |
| review | `macss-review` — **planned** | a verdict on that PR |

The first three form a closed loop already: the diagnosis and the plan are
published on the issue whose body froze at DoR, and the PR references it, so the
chain reads request, contract, diagnosis, plan, code. What it does not have is
anyone checking the last link.

**The reviewer is an AI agent, and that is the point.** A human review is not
reproducible: two reviewers, or the same reviewer twice, apply different
standards to the same diff. An agent review is deterministic to the extent that
its prompt is specific — which makes `macss-review` a *contract*, in the same
sense the specification is a contract, and makes it improvable in the same way:
when a defect class gets through, the prompt gains a rule and every future
review inherits it.

This is the same reason the gates verify artifacts rather than signatures. A
signature records that someone looked; a gate records what was checked.

Two things this must not become:

- **A second opinion nobody reads.** GitHub already fires an automatic review on
  PR creation. `macss-review` has to say something that review does not, or it
  is noise with a MACSS logo on it. What it can say is what a generic reviewer
  cannot know: whether the code satisfies *this issue's* acceptance criteria,
  whether the plan's stages were actually verified, whether the diff strays
  outside the scope the specification declared excluded.
- **A gate that blocks on style.** Review reports; a human decides. The DoD
  keeps its human approvals — QA verifying by checkout and the Product Owner
  signing off on the acceptance criteria. `macss-review` sits before those, not
  in place of them.

The open question is what it reads. A review that only sees the diff cannot
check any of the three things above. It needs the issue: the frozen body for the
contract, the comments for the diagnosis and the plan. That is exactly why those
were moved onto the issue in 0.5.0.

### The relationship with inquiry: laboratory and product

MACSS is **in production**. It has to work on its own, for someone who installs
nothing else. Inquiry is a **scientific and engineering project**: a state
machine that puts the same method under enforced gates, instrumented, free to
evolve at its own pace.

The relationship is **one-directional**. Inquiry is the laboratory where the
method is refined; MACSS inherits the result. When something is proven there, it
is written into a MACSS skill. Value flows research → product, decided by a
human, at editorial pace.

**MACSS therefore never references inquiry.** Not in a skill, not in a command,
not as an optional enhancement. Naming a second CLI inside a production tool's
instructions is an invitation to install it, and requiring a second install is
exactly the coupling this decision removes. The implementation skills are
complete on their own.

What is shared is **doctrine** — `analyze → plan → execute`, already documented
in the engineering handbook. What is never shared is the **contract**: no gate
rule, event name or artifact schema is restated in MACSS. Doctrine can safely
live in two places; a contract cannot. That is what lets inquiry rewrite its FSM
without touching anything here.

One-directional does not mean derivative. `review` has no counterpart in
inquiry's state machine — the laboratory's states are `analyze`, `plan`,
`execute` — so it is the first phase to originate in the product. Nothing about
the relationship forbids that: MACSS may not *depend* on inquiry, which is a
different claim from MACSS may not *lead* it.

The cost is a manual sync point: a lab improvement reaches MACSS when someone
ports it into a `SKILL.md`. That is deliberate, and it is what buys MACSS the
ability to stand alone.

Should MACSS later gain a `macss implementation` module that drives the method
itself, it belongs here and needs no engine from elsewhere. Building a
`macss fsm` would not — that re-absorbs the laboratory.

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
`macss project create` producing a project that satisfies
`code/book/src/project-structure.md`.

The root-level `macss create` alias shipped deprecated in 0.3.0 and was removed
in 0.5.0: `project` is where scaffolding lives, and a second name for it only
made the grammar ambiguous about which nouns own what.

## Stage 6 - The Written Record: Two Books

MACSS has a second laboratory, and it works exactly like the first.

`cacsi-dev/handbook` is where the methodology is refined **against a real
company** — a real Product Owner who finds the requisition form bureaucratic, a
real QA who has to run the gate on a Friday, real deploys to real servers. That
pressure is what makes the method true rather than tidy, and it is the same role
inquiry plays for the CLI: the place where something is proven before it is
inherited.

| Laboratory | Product | Refined against |
|---|---|---|
| `inquiry` | the `macss` CLI | an FSM with enforced gates, instrumented |
| `cacsi-dev/handbook` | the `macss` book | one company's actual practice |

The rules carry over unchanged, because they are the same rules:

- **One-directional.** The handbook never depends on the macss book; the macss
  book never references the handbook. A public book citing a private one is a
  dead link with extra steps.
- **Doctrine is shared, specifics are not.** The lifecycle, the gates, the
  one-requirement-one-issue model — those generalize. Santa Isabel's product
  catalogue, `macss-devops` cmdlets, the `@cacsi-dev/approvers` team, the UAT
  server names — those stay in the laboratory.
- **Editorial pace, decided by a human.** A chapter reaches the macss book when
  someone generalizes it, not automatically.

### Book two: `macss`

**This book already exists** — `code/book/`, and it is already generic: not one
mention of CACSI or Santa Isabel in it. It is not a book to write from scratch;
it is a book to **finish**.

What it has: the architecture (Parts I and II), and the parts of the method that
were always general — development flow, testing and quality gates, CI/CD,
the human + AI delivery model, governance and ADRs.

What it lacks is the lifecycle we spent 0.4.0 and 0.5.0 building commands for.
The handbook now documents every stage from `need` to `cd`, plus the
environments chapter; none of that has been generalized across yet. The gap is
concrete: a reader of the macss book can learn the architecture and can run
`macss requisition new`, but cannot read why the requisition is a form the
Product Owner fills himself.

### Book one: `codito`

A glossary and the diagrams, written to be **understood on first reading** —
the register of a children's book, deliberately.

This is not a simplified duplicate of `glossary.md` (328 lines, already in book
two). It is a different instrument for a different moment: what you hand someone
on day one, before they can hold the whole model in their head. Book two defines
terms for a reader who already accepted the architecture; codito has to make
someone *want* to.

Ordered first because it is read first, and because the constraint runs the
useful direction: a term that cannot be drawn, or cannot be explained plainly,
is usually a term that is not yet understood. Writing codito is a test of the
vocabulary, and the vocabulary is already an asset the CLI ships
(`assets/vocabulary/`) — which is where a drift guard would attach.

### Open

- Where codito lives. `code/book/` is a Pandoc pipeline for one book; a second
  needs either a sibling directory or a build that takes a target.
- Whether the shared diagrams (`code/book/src/diagrams/`) are duplicated or
  referenced. They will drift if duplicated, and this repository has learned
  that lesson more than once.
- Language. The macss book is in Spanish; the repository's rule is English for
  everything new. That contradiction is real and predates this stage.

## Long-Term Direction

The repository is expected to remain the root of the architecture ecosystem.

That means the long-term shape of MACSS is larger than a library and larger than
the current CLI package. It is the place where the architecture, its tooling,
its automation, and its educational assets converge — the last of these being
the two books of Stage 6.

## Immediate Next Step

The next immediate step is to finalize the `api` module contracts after the
already achieved subsystem milestone, so implementation and documentation remain
synchronized.

The key decision already taken is this:

- the official command remains `macss`
- subsystem tooling lives under modules
- GraphQL compile mode for `modular_api` belongs under `macss api graphql ...`
