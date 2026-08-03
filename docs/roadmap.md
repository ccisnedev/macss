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

The near-term focus of the methodology axis is **Stage 7 - Environments**. The
lifecycle stages that remain unbuilt all operate against running systems, so
they wait until dev, uat, prod and demo exist to operate against.

A fourth axis is incubating, not being built: **Stage 8 - `modular_agent`**, the
agent runtime that is `modular_api`'s sibling. It has a laboratory and a name,
and deliberately no code in this repository yet.

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
| implementation | skills | `macss-analyze` / `macss-plan` / `macss-execute` — **shipped** (0.5.0) |
| ci | none — the platform's | GitHub Actions. MACSS states the expectation; it does not own the runner |
| review | none — the platform's | a gate, methodological. Fires on the PR, so the instrument is platform review with custom instructions, not a MACSS command |
| verification | `macss verification` | planned |
| definition of done | `macss dod` | planned — composes review, verification and the human approvals |
| deploy | `macss deploy` | planned — delegates to `macss-devops` (Stage 3.5) |

There is no `macss issue` module. One requirement is one issue, and the issue is
a **consequence** of publishing the requisition, not a separate artifact someone
composes: `requisition publish` creates it, `specification publish` appends the
contract to it, and at DoR the body freezes. A module for it would imply the
issue could be authored independently of the request it carries.

Shared verbs where they make sense: `new` (open the artifact), `check` (run the
stage gate), `publish` (materialize it on GitHub, `--plan` then `--apply`).
Every argument is explicit and named — `--issue 40`, never a positional.

### Implementation is three phases. Review is a gate outside it

Implementation is the one stage MACSS serves with skills rather than commands,
because what it needs is judgement rather than mechanism. It has **three**
phases, and they are complete:

| Phase | Skill | Produces |
|---|---|---|
| analyze | `macss-analyze` | the diagnosis, as a comment on the issue |
| plan | `macss-plan` | staged work, each stage with an executable verification |
| execute | `macss-execute` | the code, under TDD, and the PR |

They form a closed loop: the diagnosis and the plan are published on the issue
whose body froze at DoR, and the PR references it, so the chain reads request,
contract, diagnosis, plan, code. **When execute finishes, the problem is
solved.** Nothing is pending inside implementation.

**Review is a gate, not a fourth phase.** It sits outside implementation and can
send the work back into it. The distinction is not bookkeeping — it is what the
two things check:

- Implementation answers *did we solve the problem the specification stated?*
  That question is settled by the contract, and the contract was frozen at DoR.
- Review answers *is this how we build things here?* Standards, conventions,
  preferences, the shape of an abstraction, a pattern this codebase already
  uses. **None of that is in the specification**, and none of it could be: it is
  not knowable when the request is written.

That is precisely why inquiry's state machine has no `review` state, and why
that is correct rather than an omission. An FSM for the implementation stage
should not contain a gate that belongs outside it — a state machine that models
its own escape hatch stops being a model of the stage.

So the loop is: implementation delivers → review judges → either it passes, or
it returns to implementation with something to change. A returning issue does
not re-open the requisition. The contract still holds; what changed is how the
solution is built.

### The review is methodological, and it is not a MACSS command

**The reviewer is an AI agent, and that is the point.** A human review is not
reproducible: two reviewers, or the same reviewer twice, apply different
standards to the same diff. An agent review is deterministic to the extent that
its prompt is specific — which makes the review instructions a *contract*, in
the same sense the specification is a contract, and improvable the same way:
when a defect class gets through, the instructions gain a rule and every future
review inherits it.

This is the same reason the gates verify artifacts rather than signatures. A
signature records that someone looked; a gate records what was checked.

**There is no `macss review` command and no `macss-review` skill**, and the
reason is a constraint the review has that no other stage does: **it has to fire
when the pull request appears**, without anyone choosing to run it. A command
requires someone to type it, and the person most likely to forget is the one who
just wrote the code.

That forces the instrument to live where pull requests live — the platform's own
review, configured with custom instructions. Which means accepting the coupling
that every other part of MACSS refuses: the skills are deliberately portable
across assistants, and this one is not. The trade is deliberate. A portable
review that runs when remembered is worth less than a coupled review that always
runs.

So MACSS states the expectation and supplies the content; the platform supplies
the trigger. The same shape as `ci` in the stage table: MACSS does not own the
runner.

#### Two layers, because the standards have two sources

- **Generic to MACSS.** Is this actually the architecture — the layer boundaries,
  the request flow, the module model? A project can adopt the file structure and
  violate the design inside it, and nothing else in the lifecycle would notice.
- **Specific to the project.** Conventions, preferred abstractions, the patterns
  this codebase already uses. Not knowable in advance, which is why the
  instructions have to be **extensible** rather than fixed.

The generic layer is a MACSS asset. The specific layer belongs to the project
that owns the code, and the design has to let it extend without forking.

#### Open

- **How custom review instructions are configured.** GitHub Copilot's code
  review reads repository instruction files; the exact filenames, the path
  scoping, and whether they compose or override needs verifying against current
  documentation before anything is written against it.
- **Whether the review can read the issue.** A review that sees only the diff
  cannot check whether the code satisfies *this issue's* acceptance criteria,
  whether the plan's stages were verified, or whether the diff strays into scope
  the specification excluded. Those are the checks worth having — a generic
  reviewer already finds generic things — and they need the frozen body and the
  comments. Whether platform review has that reach is the question that decides
  how much of this is achievable.

What it must not become is **a gate that blocks on taste**. Review reports; a
human decides. The DoD keeps its human approvals — QA verifying by checkout and
the Product Owner signing off on the acceptance criteria.

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

`review` is a case worth naming, because its absence from inquiry looks like a
gap and is not one. The laboratory's states are `analyze`, `plan`, `execute` —
the implementation stage, and nothing else. A gate that sits outside that stage
has no business inside a machine that models it. Both tools agree on the
boundary; only MACSS also builds the thing on the far side of it.

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
`code/books/macss/src/es/project-structure.md`.

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

**This book already exists** — now `code/books/macss/`, and it is already
generic: not one mention of CACSI or Santa Isabel in it. It is not a book to
write from scratch; it is a book to **finish**.

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

The layout exists (`code/books/codito/`); the content does not yet.

Ordered first because it is read first, and because the constraint runs the
useful direction: a term that cannot be drawn, or cannot be explained plainly,
is usually a term that is not yet understood. Writing codito is a test of the
vocabulary, and the vocabulary is already an asset the CLI ships
(`assets/vocabulary/`) — which is where a drift guard would attach.

### Language: the rule applies to the design, not to the content

The apparent contradiction — a Spanish book in a repository whose rule is
English for everything new — dissolves once the two are separated.

**The design is language-agnostic and written in English.** Directory names,
slugs, code, comments, commit messages, the check that walks the tree: none of
them may assume a language exists, and all of them are written in one. That is
why `SUMMARY.md` carries slugs and not titles: a title is content.

**The content ships in English and Spanish**, with more possible later. Neither
is the source and neither is the translation — they are editions. Adding a third
is adding `src/<lang>/`, and nothing in the design learns its name, because
`books_layout_test` enumerates the directory instead of listing what it expects.

This is the same split the CLI already makes. `assets/vocabulary/<lang>.yaml`
holds words; the gate that matches them holds none. Section numbers stayed out
of the vocabulary files for exactly this reason — they are structure, not
language.

### Open

- Whether the shared diagrams (`code/books/macss/diagrams/`) stay shared. Their
  labels are technical terms today, which is why one copy serves every edition;
  a diagram that acquires prose would break that.
- Which edition leads for a given chapter. The lifecycle chapters have to be
  generalized out of the handbook, which is written in Spanish, so `es` will
  usually be written first — but nothing in the design says it must be.

## Stage 7 - Environments: dev, uat, prod, demo

`verification`, `dod` and `deploy` stay planned, and deliberately so. Building
commands for stages the method has not yet been exercised through would encode
guesses as contracts — the opposite of how `requisition` and `specification`
arrived, which was after the handbook had documented what they had to do.

What comes before them is the ground they stand on: the four environments the
handbook's environments chapter defines — **dev**, **uat**, **prod**, **demo**.

They are what the remaining stages actually operate against. `verification` is
QA checking out a branch and validating acceptance criteria *somewhere*, and the
Product Owner signs off in **uat**. `deploy` promotes *between* environments,
and cannot be specified without knowing what it promotes between. `dod` composes
approvals that are given about a running system, not about a diff.

Defining them is not CLI work yet. It is standing them up and using the method
against them long enough to learn what a command would have to do.

## Stage 8 - `modular_agent`: the Agent Runtime

MACSS has a second runtime product coming, and it is being incubated the same way the
method was.

`modular_api` ships what every API in the ecosystem always needs — separation of
concerns, GraphQL, metrics, logs, OTel. **`modular_agent` is its sibling**: what every
agent always needs — a scheduler, durable state, a tool layer, memory, observability, and
the role expressed as versioned configuration. It will live in its own repository, as a
runtime product user projects embed, and its CLI surface will be `macss agent ...`.

### Why the name, and not a new brand

`architecture.md` rule 5: do not create a new top-level product name when the capability
is a subsystem. An agent runtime is an ecosystem component, exactly like `modular_api`,
so it inherits the ecosystem's naming rather than opening a brand.

Names for *roles* were rejected for the same reason. A runtime that can be a router, an
operator or an implementer cannot be called `executor` — that collapses the runtime into
one of its own roles.

### A third laboratory

| Laboratory | Product | Refined against |
|---|---|---|
| `inquiry` | the `macss` CLI | an FSM with enforced gates, instrumented |
| `cacsi-dev/handbook` | the `macss` book | one company's actual practice |
| **`cacsi-dev/helper`** | **`modular_agent`** | **a helpdesk agent running in production** |

The rules carry over unchanged: one-directional, doctrine shared but never contracts, and
promotion at editorial pace decided by a human.

**Nothing is extracted yet, and that is the point.** `modular_agent` gets pulled out when
a *second* agent demands it. Generalizing a framework from N=1 produces a framework shaped
like its only case — here, a helpdesk.

### What the laboratory has already established

Enough is known to say what belongs in the runtime and what does not:

- **Generalizes.** The harness / thinking-layer split behind a port; tools as CLI with a
  discoverable catalogue; the role as versioned configuration; durable state with
  recovery; **memory as a framework schema rather than a per-project design**;
  observability and evals as gates.
- **Does not generalize.** The priority scheduler with aging and blocking. It exists
  because a helpdesk has many concurrent conversations with humans who answer slowly. An
  agent that implements code has one deep task and no such wait.

### How it earns the name: the five layers of an agent

`modular_api` earns "modular" because a module is a **vertical slice** through every layer,
and the proof is that extracting one leaves something that works alone. `modular_agent`
has to meet the same test or the name is decoration.

An agent's horizontal layers are not an application's. They fall out of the questions that
must be answered before it can act:

| Layer | Question |
|---|---|
| **Tools** | What can it do? |
| **Skill** | What does it know? |
| **Memory** | What does it remember? |
| **Policy** | What is it not permitted to do? |
| **Evals** | How do we know it does it well? |

A module is the vertical cut through those five, for **one domain**:

```text
code/agent/
├── modules/
│   ├── credits/
│   │   ├── tools/          # bindings to the domain's CLI
│   │   ├── skill.md        # the procedure, written for the model
│   │   ├── memory/         # its tables, inside the memory schema
│   │   ├── policy.yaml     # the grant: bounds, quotas, prohibitions
│   │   └── evals/          # how this domain is verified
│   └── accounts/
└── roles/
    └── operator.yaml       # modules: [credits, accounts]
```

### Parity: `agent` is the fifth canonical layer

```text
code/db/modules/credits      # the schema
code/api/modules/credits     # the use cases
code/app/modules/credits     # the screen
code/cli/modules/credits     # the commands
code/agent/modules/credits   # what the agent can do with them
```

Five layers, one name — which is what makes `agent` canonical rather than a folder someone
added. The canon invariant extends on its own:

> **If `agent/modules/X` exists, `cli/modules/X` must exist** — because the agent reaches
> its domain through the CLI, and an agent module with no CLI to serve it is an agent with
> no hands.

A second invariant comes from ADR 0006 and is what makes the grant model verifiable rather
than aspirational:

> **If `agent/modules/X/tools/` exists, `agent/modules/X/policy.yaml` must exist.**
> A tool without a declared policy is a capability nobody authorized.

### The extraction test passes

Lift `modules/credits` into a new project and you get a credits specialist: its own
container, its own memory, its own grants, its own evals. **Extracting an agent module
produces another agent** — the exact counterpart of extracting an API module into a
microservice. Composing several produces a generalist. The role is the manifest that says
which ones load.

### Plugins are shipped; modules are written

`modular_api` separates plugins (health, metrics, OpenAPI, GraphQL — technical
capabilities) from modules (domain slices). `modular_agent` keeps the same split:

- **Plugins ship with the package** — thinking-layer providers, memory backends, sensor
  types (poll, webhook, queue), tool transports.
- **Modules are written by whoever adopts it.** The framework never guesses a domain.
- **The core is what nobody rewrites** — scheduler, durable state, the thinking port, the
  module loader, observability, and the base `memory` schema.

### It has no API of its own

`modular_agent` exposes no service. It sits in its own loop waiting for events it can
handle — the same way a person waits for work to arrive. Observability binds to localhost;
there is no control endpoint, because behaviour is deployed rather than edited (ADR 0005,
ADR 0019 in helper).

### Working hours are a first-class concern

If the agent behaves like a person doing a job, it needs what a person doing a job has: a
schedule. The core carries a **calendar** — timezone, weekly shift, and non-working days
including local holidays — and the scheduler will not dispatch user tasks outside it.

This is not a courtesy. It bounds cost, it stops the agent from setting a response
expectation the business cannot meet at 3am, and it makes the agent's behaviour legible to
the humans working beside it. It also composes with ADR 0006: **a grant can be
time-bounded**, so the calendar is part of the policy layer, not a separate feature.

System tasks (`poll`, `self_check`) keep running off-hours, so no event is lost: stopping
the sensing loses work, stopping dispatch only defers it.

**The out-of-hours notice is not the agent's job**, and that follows from ADR 0006 rule 7.
If the agent is what says *I am not attending right now*, nothing gets said when the agent
is broken rather than off-shift. The notice belongs to the facade — no model in the path,
nothing to talk out of it, and it still works during a deploy. When the night shift needs
to do more than announce itself, that *is* agent work, and the shape is a role rather than
an exception: **the calendar selects the role, it does not filter tools.**

### Languages: Python and TypeScript

`modular_api` ships in Dart, TypeScript and Python. `modular_agent` will ship in
**Python and TypeScript only.**

The reason is the thinking layer: its provider ecosystem is Python-first and TypeScript-
second — Google's ADK, for instance, covers Python, TypeScript, Go and Java. **Dart has
none.** A Dart edition would mean writing the provider layer from scratch before writing
any agent, which is a different project. Go and Java are supported by providers but are not
in the MACSS language set today.

### Two deployment shapes, and neither is an exception

The question that opened this stage — *does MACSS need a separate archetype for agents?* —
resolves without one. `agent` is a canonical layer, and there are two shapes of project
that use it:

- **Agent in project.** `code/agent/` beside the other four layers, with full name parity.
  This is the normal case, and `macss project check` verifies it like any other layer.
- **Detached agent.** The domain belongs to a different product, so the project holds
  `code/agent/` and a `code/db/` with the `runtime` and `memory` schemas, and **declares
  its domain CLI as a dependency**. Parity is verified against an external CLI instead of
  a sibling `code/cli/`.

`cacsi-dev/helper` is the second shape: its domain is H.E.L.P., reached through `hd`. It is
not an exception to the canon — it is the canon's second case, which is what the laboratory
was for.

What stays true in both: **an agent owns no domain.** Its `db` holds what the agent *is* —
`runtime` (process control) and `memory` (what it knows) — never the business. That is the
property that lets one framework serve every domain: same runtime, same memory, same
observability, a different CLI.

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
