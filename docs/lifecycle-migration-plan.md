# Operational plan — Moving the software lifecycle into the `macss` CLI

- **Status:** approved, in progress
- **Date:** 2026-07-31
- **Repositories affected:** `macss/macss`, `silicon-brained-machines/inquiry`, `cacsi-dev/handbook`
- **Baseline:** macss `main` at `be19042` (merge of PR #3)

---

## 1. Context

MACSS is not only an architectural framework. It is a mental model for building every layer of a
software system, and therefore for the **entire lifecycle**:

```
requisition → specification → issue → implementation → verification → deploy
```

That lifecycle is documented in the engineering handbook:

| Stage | Diagram | Chapter |
|---|---|---|
| requisition → specification (DoR) | `flujo-requerimiento-dor.mmd` | `ingenieria_de_requisitos.md` |
| implementation → verification (DoD) | `flujo-desarrollo-verificacion-dod.mmd` | `desarrollo_software.md` |
| merge → deploy | `flujo-merge-deploy.mmd` | `despliegue_operacion.md` |

`inquiry` was designed for **one** of those stages. It is the state machine that drives an already
specified issue through the `analyze → plan → execute` loop with verifiable gates. Over time it
absorbed territory that does not belong to it — the `iq specification` and `iq issue` commands, which
are pre-implementation and owned by QA, and the deployment of the skills for every stage. The result
is an inverted split: inquiry carries the vocabulary of the whole lifecycle, while macss, which
defines that vocabulary, does not execute any of it.

**Goal:** move the lifecycle into the `macss` CLI, give `inquiry` its original purpose back, and
close the remaining functional gap in macss — without duplicating contracts across repositories.

## 2. Starting point

PR #3 (`spec/api-graphql-cli` → `main`) left macss at **chassis parity** with inquiry. The two CLIs
are structurally equivalent today:

| | macss `0.1.0` | inquiry `0.21.1` |
|---|---|---|
| Language | Dart | Dart |
| SDK | `modular_cli_sdk ^0.3.3` + `cli_router ^0.1.0` | identical |
| Pattern | `Input` / `Output` / `Command` + `params: [CliParam…]` | identical |
| Registration | `cli.module('x', (m) => buildXModule(m, …))` | identical |
| Help | rendered by the SDK from the command catalog | identical |
| Assets | next to the binary, resolved from `Platform.resolvedExecutable` | identical |
| Alias | `macss` + `ma` (symlink / `ma.cmd`) | `inquiry` + `iq` |

**Operational consequence: this migration is a mechanical port, not a rewrite.** The code being moved
compiles against the same SDK with the same types.

Current macss surface: `create`, `doctor`, `upgrade`, `uninstall`, `version`, `help`,
`api graphql compile`, and the TUI on the empty route.

> **`code/ui` → `code/app`: already done.** There is not a single reference to `code/ui` left in any
> of the three repositories. The scaffold stamps `code/{infra,db,api,app}` and the documented canon
> says `code/app`. No work pending on this point.

## 3. Settled decisions

| # | Decision | Consequence |
|---|---|---|
| D1 | `macss` is the canonical entry point; **`ma` is the official short alias** | Already implemented in the installers. Only the README needs fixing — it currently disowns it |
| D2 | macss skills are **static** `SKILL.md` files versioned under `assets/skills/` | inquiry's generative `SkillBuilder` is not replicated |
| D3 | They are installed **once per machine**, into each assistant's own skills directory under `~/` | A project-local copy would have to be refreshed in every clone — the opposite of a rare operation |
| D4 | Skills are **thin and delegating** | They point at the live contract through commands (`iq fsm state --json`) instead of restating gate rules |
| D5 | macss = which stage and why. inquiry = how implementation is executed | Stable split, no overlap |

### On D1 — name and alias

`macss` is five characters, typeable, and it is the brand. `ma` is the right alias: two letters like
`gh` or `iq`, mnemonic, and **free of collisions** with any standard Unix or Windows binary — unlike
`mcs`, which is the Mono C# compiler. It already exists in `code/cli/scripts/install.sh` (symlink
`ma → macss`) and `install.ps1` (`ma.cmd`). The only inconsistency is `README.md`, section
"CLI Naming Decision", which states that MACSS does *not* expose `ma` and that short aliases
*"are not the official documented contract"*.

### On D4 — why static skills do not drift

In inquiry, `iq-analyze` / `iq-plan` / `iq-execute` are **generated** at deploy time by reading
`assets/fsm/states/<phase>.yaml` and the `##` headers of the artifact templates, precisely so they
cannot fall out of sync with the FSM contract. Copying that mechanism into macss would mean
duplicating the FSM assets in another repository.

The way out is to write them at the level macss actually owns — **which stage this is, what it
produces, when it is done** — and delegate the mechanics to commands that query the live contract:

```
1. `iq fsm state --json`  → do exactly what its `next` field says
2. `iq ape prompt --name <operator>` → read the method and apply it
3. …
4. `iq fsm transition --event <gate>` → the CLI verifies the result
```

That text is stable across FSM changes. What does drift — the concrete gate rules and each
artifact's sections — is never copied: `iq` itself prints it on failure.

---

## 4. Migration catalog

Six items, **two parallel pull requests**: add in macss, remove the same in inquiry.

| # | Item | PR A — macss: add | PR B — inquiry: remove |
|---|---|---|---|
| 1 | `specification` | `modules/specification/**` (6 files, 873 LOC) + 2 templates | delete module + registration at `inquiry_cli.dart:18` |
| 2 | `issue` | `modules/issue/**` (4 files, 480 LOC) + 2 templates | delete module + registration at `inquiry_cli.dart:17` |
| 3 | skill `specification` | `assets/skills/macss-specification/SKILL.md` | `_buildSpecification()` + its `phaseSkillNames` entry |
| 4 | skill `analyze` | `assets/skills/macss-analyze/SKILL.md` | entry in `SkillBuilder.phases` |
| 5 | skill `plan` | `assets/skills/macss-plan/SKILL.md` | entry in `SkillBuilder.phases` |
| 6 | skill `execute` | `assets/skills/macss-execute/SKILL.md` | entry in `SkillBuilder.phases` |

**Total volume:** 11 Dart files / 1,404 LOC, 6 template assets, 7 test files / 1,030 LOC.

> **Parallel in development, sequential in merge.** PR B cannot land before PR A, or users lose the
> commands during the intervening window.

### What stays in inquiry

`modules/fsm`, `modules/ape`, `modules/implementation`, `src/cycle_context.dart`, the APEs
(`assets/apes/*.yaml`), the state contracts (`assets/fsm/**`), the `diagnosis` and `plan` templates,
the agents (`assets/agents/**`), and inquiry's own `kritik`, `legion`, and `research` skills.

### The seam — verified by grep, not inferred

Outside the two modules, the **only** references to `specification`/`issue` in inquiry are the two
module registrations in `lib/inquiry_cli.dart:17-18`. Everything else is internal traffic between the
pair:

```
modules/issue/commands/new.dart:19-20      → ../../specification/{slug,workspace}.dart
modules/issue/commands/publish.dart:18-19  → ../../specification/{slug,workspace}.dart
modules/specification/specification_gate.dart:14 → ../issue/front_matter.dart
```

Zero imports from `fsm/`, `ape/`, `implementation/`, or `cycle_context.dart`. Zero `git` calls. Their
tests run without a git repository (they use `Directory.systemTemp` and an injected clock). **The
pair moves as a unit and drags nothing from the engine.**

---

## 5. PR A — macss: add

### A.1 Skill infrastructure

**Extend `Assets`.** `code/cli/lib/assets.dart` has `path`, `loadString`, `fileExists`, and
`directoryExists` — it is **missing `listDirectory()`**, needed to enumerate `assets/skills/`.

**Static skills** under `code/cli/assets/skills/<name>/SKILL.md`:

| Skill | Stage | Source of the text |
|---|---|---|
| `macss-specification` | specification + issue | `skill_builder.dart::_buildSpecification()` (verbatim), with `iq …` → `macss …` |
| `macss-analyze` | implementation | rendered `build('analyze')`, trimmed per D4 |
| `macss-plan` | implementation | rendered `build('plan')`, trimmed per D4 |
| `macss-execute` | implementation | rendered `build('execute')`, trimmed per D4 |

**The `skill` module:**

```
code/cli/lib/modules/skill/skill_builder.dart      # route registration
code/cli/lib/modules/skill/commands/deploy.dart    # macss skill deploy
code/cli/lib/modules/skill/commands/list.dart      # macss skill list
code/cli/lib/modules/skill/commands/clean.dart     # macss skill clean  (see §7)
```

Declared contract for `deploy`:

| Param | Type | Notes |
|---|---|---|
| `--host` | string, `allowed: [claude, opencode]` | Optional. Without it, every assistant detected in `~/` |

Only assistants whose skills-directory convention is actually known are offered;
guessing would create trees in a user's home that nothing reads. A host counts as
installed when its config root exists (`~/.claude`, `~/.config/opencode`), so a
bare `deploy` skips what is not there while `--host` forces it, priming a fresh
setup. Writes `<skills dir>/<name>/SKILL.md` idempotently, reporting
`created` / `updated` / `exists`. Registered in `macss_cli.dart`:

```dart
cli.module('skill', (m) => buildSkillModule(m, assets: assets));
```

**Integrate with `create`:** add to `assets/templates/project-base/.gitignore`:

```
# MACSS
.macss/
docs/requisitions/
```

### A.2 The `specification` and `issue` modules

| Source (inquiry) | LOC | | Source (inquiry) | LOC |
|---|---|---|---|---|
| `lib/templates/template_resolver.dart` | 51 | | `lib/modules/issue/issue_builder.dart` | 41 |
| `lib/modules/specification/slug.dart` | 35 | | `lib/modules/issue/front_matter.dart` | 78 |
| `lib/modules/specification/workspace.dart` | 99 | | `lib/modules/issue/commands/new.dart` | 169 |
| `lib/modules/specification/specification_gate.dart` | 361 | | `lib/modules/issue/commands/publish.dart` | 192 |
| `lib/modules/specification/specification_builder.dart` | 43 | | | |
| `lib/modules/specification/commands/new.dart` | 192 | | | |
| `lib/modules/specification/commands/check.dart` | 143 | | | |

Plus `assets/artifacts/{requisition,specification,issue}.template.{en,es}.md` (6 files).

Resulting routes: `macss specification new|check`, `macss issue new|publish`.

**Changes made while porting:**

1. **State pointer:** `.inquiry/specification.yaml` → **`.macss/specification.yaml`**
   (`workspace.dart::activeRequisitionPath`). The only observable behavioral change.
2. **Gitignore:** guarantee `docs/requisitions/` and `.macss/`; **drop** `.inquiry/` and
   `cleanrooms/`, which belong to the FSM engine.
3. **Text:** every help message, error, and remediation that says `iq …` becomes `macss …`.

> The `.template.es.md` assets are **existing Spanish content** and are ported verbatim. The
> bilingual `--lang` contract is part of the feature: specifications are written in the language of
> the business. Everything new in this plan — code, comments, docs — is English.

### A.3 Mandatory repository checklist

Conventions that break tests when skipped:

- [ ] Add every new route to the expected list in `test/help_command_test.dart:25-30`
      (the catalog drift guard).
- [ ] Add root-level commands to the **hand-maintained** banner in
      `modules/global/commands/tui.dart` (covered by `tui_test.dart`).
- [ ] Add new assets to `templatePaths` in `modules/global/commands/doctor.dart:122`.
- [ ] New tests in **both** styles used by `create_test.dart`: a unit group (build the `Input` and
      call `execute()`) and a contract group (through a real `ModularCli`, asserting that `--bogus`
      exits 7 with `unknown option` and produces **no** side effects).

### A.4 Tests to port

`specification_new_command_test` (135), `specification_check_command_test` (131),
`specification_gate_test` (355), `specification_slug_test` (54), `specification_workspace_test` (83),
`issue_command_test` (220), `template_resolver_test` (52). They keep the injected clock
(`now: () => DateTime(2026, 7, 9)`) so dated folders stay deterministic.

### Acceptance criteria — PR A

The manual walkthrough in §10 passes end to end; the 1,030 ported LOC are green; `macss help` lists
every new route.

---

## 6. PR B — inquiry: remove

- [ ] Delete `lib/modules/specification/**` and `lib/modules/issue/**`.
- [ ] Remove both `cli.module(...)` calls and their imports in `lib/inquiry_cli.dart:17-18`.
- [ ] Delete `lib/hosts/skill_builder.dart` entirely, along with its consumers:
  - `lib/hosts/deployer.dart::HostDeployer._deploySkills` stops iterating `phaseSkillNames`; it
    **keeps deploying** the agents and `kritik` / `legion` / `research`.
  - `lib/modules/global/commands/doctor.dart::_getExpectedSkills()` drops the phase-skill
    expectation.
- [ ] `lib/src/gitignore.dart`: remove `docs/requisitions/`.
- [ ] Delete `test/specification_*_test.dart`, `test/issue_command_test.dart`,
      `test/template_resolver_test.dart`, `test/skill_builder_test.dart` (263 LOC); adjust
      `test/deployer_test.dart`, `test/doctor_test.dart`, `test/help_command_test.dart`, and
      `test/cli_contract_test.dart`.

> **`iq host get` is kept.** It only loses the four migrated skills; the agents and inquiry's own
> skills keep deploying as before.

### Acceptance criteria — PR B

`iq help` no longer lists `specification` or `issue`; `iq doctor` no longer demands the phase skills;
`iq host get` still deploys agents + `kritik`/`legion`/`research`; a full FSM cycle
(`iq implementation start --issue N` → analyze → plan → execute) still passes its gates.

---

## 7. PR C — closing the functional gap: the `project` module

**Independent of A and B.** This is not migration: it is functionality macss needs and that neither
CLI has today.

### 7.1 Gap analysis, macss ← inquiry

| inquiry capability | In macss today | Gap |
|---|---|---|
| `iq init` — prepare an **existing** repository (config + gitignore) | only `macss create`, which assumes a new project | **Yes** → §7.3 |
| `iq doctor` checks git, `gh`, authentication, deployments, expected skills | `macss doctor` only checks its own binary and assets | **Yes** → §7.4 |
| `iq host get` / `iq host clean` | `macss skill deploy` (PR A) covers `get` | Partial → `skill clean` missing |
| `iq fsm` / `iq ape` / `iq implementation` | — | **No**: stays in inquiry by design (D5) |

### 7.2 The canon is already executable

`code/book/src/project-structure.md` does more than draw the tree: it closes with four **verifiable
invariants**, which are the specification for this command. The standard does not need to be
invented.

```
- If `api/modules/X` exists, `db/modules/X` must also exist.
- Client modules mirror backend modules by name.
- Documentation is never mixed with code.
- Decisions are recorded near the architecture they affect.
```

**Drift already detected:** the canon requires `CHANGELOG.md` at the root — it appears both in the
tree and in the "Materialized by `macss create`" section — but `create.dart:155-157` only stamps
`README.md`, `.gitignore`, and `.gitattributes`. **`macss create` does not currently produce a
project that satisfies its own documented canon**, and nothing detects it. This PR fixes that
alongside the checker that would have caught it.

### 7.3 `macss project check` and `macss project adopt`

Grammar is `macss <module> <surface> <action>` — module `project`, verb at the leaf. ✓

**`macss project check --path=.`** — read-only diagnosis. Reuses the model in `doctor.dart`
(`DoctorCheck{name, status, detail, remediation}`), which currently has `CheckStatus{ok, error}` and
needs a third value, **`warning`**:

| Status | Meaning | Example |
|---|---|---|
| `ok` | Satisfies the canon | `code/db/` present |
| `error` | Something required is **missing** and is auto-fixable | no `CHANGELOG.md`; no `docs/adr/` |
| `warning` | Something is **extra** or deviates; needs human judgement | `code/api/modules/sales` without `code/db/modules/sales`; a stray folder in `code/` outside the canon |

Exit code ≠ 0 when any `error` is present, matching today's `doctor`.

**`macss project adopt --path=. [--plan|--apply]`** — applies what is missing, reusing the Terraform
idiom the repository already uses in `issue publish` (`--plan` by default, previews; `--apply`
executes). This is the command that answers *"what if I want an existing project to adopt MACSS?"*.

> **Safety rule: `adopt` never deletes.** It only creates what is missing. Anything extra is reported
> as a `warning` and left to the team's judgement — a `code/legacy/` folder may be deliberate debt,
> and a tool has no context to decide that.

How it relates to the existing commands:

```
new project        →  macss create  --path=.
existing project   →  macss project check   --path=.     (what is missing / extra?)
                      macss project adopt   --path=. --plan
                      macss project adopt   --path=. --apply
```

### 7.4 Extend `macss doctor`

`macss doctor` stays **the doctor of the CLI**, not of the project — that separation is exactly what
was missing. It gains the external dependency preflight that only inquiry has today, and that the
roadmap already called for (Stage 3.5):

`git`, `gh` (invoked by `macss issue publish`), `pwsh` + `macss-devops`, `.NET` + `sqlpackage`,
Docker, Flutter — each with its exact install command as the `remediation`.

### 7.5 `macss skill clean`

Counterpart to `deploy`, equivalent to `iq host clean`. Also needed to clean up the orphaned `iq-*`
skills after PR B (see §11).

### Acceptance criteria — PR C

`macss project check` on a freshly created `macss create` project exits **0** (that is: the scaffold
satisfies its own canon, `CHANGELOG.md` included); on a foreign repository it enumerates what is
missing and what is extra; `macss project adopt --apply` brings it to exit 0 without deleting
anything.

---

## 8. Documentation

### macss

- [ ] `README.md`, section "CLI Naming Decision": promote `ma` to official short alias instead of
      disowning it. Document the new surface.
- [ ] `docs/macss_skills.md`: close the draft with D2–D4. This resolves its explicit open item,
      *"Diseñar estructura de `code/skills/` en el repositorio macss"*.
- [ ] `docs/adr/0003-lifecycle-ownership-and-local-skills-directory.md`: new ADR (0001 and 0002 set
      the practice) recording **why** the lifecycle lives in macss and **why** skills are installed
      once per machine rather than per repository.
- [ ] `docs/adr/0004-project-canon-is-executable.md`: why the canon in `project-structure.md` is
      verified by `macss project check` instead of remaining prose.
- [ ] `docs/architecture.md`: the grammar gains `specification`, `issue`, `skill`, `project`.
- [ ] `docs/roadmap.md`: reflect the new stages.
- [ ] `code/book/src/project-structure.md`: link the canon to the command that verifies it.

### handbook (`cacsi-dev/handbook`)

- [ ] `book/src/chapters/ingenieria_de_requisitos.md:144` and
      `book/src/chapters/referencias.md:23,27,28` state that the `requisition.md` /
      `specification.md` templates are provided by `inquiry` → they become `macss`.

> These handbook chapters are existing Spanish content. Only the tool name changes; the surrounding
> prose is left as is.

---

## 9. Versioning and release

In each repository, bump `code/cli/pubspec.yaml` **and** `lib/src/version.dart` in the same commit —
a test enforces it (`version_sync_test.dart`).

| Repository | From | To | Reason |
|---|---|---|---|
| macss | `0.1.0` | `0.2.0` | new surface (PR A + PR C) |
| inquiry | `0.21.1` | `0.22.0` | breaking: commands and skills removed |

In macss, that bump on `main` is what triggers `.github/workflows/release.yml`.

---

## 10. Verification

### Automated — in both repositories, from `code/cli/`

```
dart pub get && dart analyze --fatal-infos && dart test
```

> `version_sync_test.dart` reads `pubspec.yaml` **relative to the cwd**: tests must run from
> `code/cli/`, not from the repository root.

CI covers `ubuntu-latest` + `windows-latest`, path-filtered on `code/cli/**`.

### Manual, end to end — in a temporary directory

```
macss create --path=.               # creates a .gitignore with .macss/, docs/requisitions/
macss project check --path=.        # exit 0 — the scaffold satisfies its own canon
ma skill list                       # the alias resolves to the same binary
macss skill deploy                  # 4 SKILL.md files per detected assistant
macss skill deploy                  # idempotent: reports 'exists'

macss specification new demo --lang es
#   → docs/requisitions/<YYYYMMDD>-demo/{requisition,specification}.md
#   → .macss/specification.yaml points at the active requisition
# (fill specification.md: ISO date §1, user stories with Given-When-Then §2, scope §3)

macss specification check           # specification_ready gate → exit 0
macss issue new alta --repo ccisnedev/macss
macss issue publish alta --plan     # prints the gh issue create without running it
macss help                          # every new route listed
macss doctor                        # git, gh, pwsh… among the verified dependencies
```

Against an **existing, foreign** repository (for example a clone of another project):

```
macss project check --path=.        # enumerates what is missing and what is extra, exit ≠ 0
macss project adopt --path=. --plan
macss project adopt --path=. --apply
macss project check --path=.        # exit 0, having deleted nothing
```

Re-run `macss create` and `macss specification new demo` to confirm idempotence (`exists` / `kept`,
nothing overwritten).

---

## 11. Risks and breaking changes

| Risk | Impact | Mitigation |
|---|---|---|
| PR B merged before PR A | Window with no `specification`/`issue` in either CLI | Sequential merge: A first, then B |
| Rename `.inquiry/specification.yaml` → `.macss/specification.yaml` | In-flight requisitions lose their active pointer | If there is live work under `docs/requisitions/`, move the YAML by hand. Document in both CHANGELOGs |
| Static implementation skills drift if the FSM changes | Stale instructions | D4: never copy gate rules or artifact sections; delegate to `iq fsm state` / `iq fsm transition` |
| Skills live in `~/`, so a repo does not pin the version its contributors run | A teammate on an older CLI has older skills | Accepted: deployment is a rare per-machine setup step, and `macss skill deploy` refreshes stale copies in place |
| `iq-*` skills already deployed under `~/.claude/skills` become orphans | Stale skills coexist with the `macss-*` ones | `iq host clean` after PR B, plus `macss skill clean` (§7.5) |
| `project adopt` against a foreign repository | Writing into a project that did not expect the canon | `--plan` is the default; `--apply` never deletes |

## 12. Open items

1. **Skill-less stages.** `verification` and `deploy` appear in the diagrams but have no skill. The
   `skill` module would accept them with no changes.
2. **Skill names.** Assumed `macss-specification`, `macss-analyze`, `macss-plan`, `macss-execute`.
   Alternative: a single `macss-implementation` instead of three.
3. **Org inconsistency in the handbook.** `introduccion.md:171` cites `github.com/ccisnedev/macss`
   while `stack.md:74` cites `github.com/macss-dev/modular_api`. Confirm whether this is intentional
   before touching the references in §8.

---

## 13. Approval

- [x] **PR A** — macss: skill infrastructure + `specification` + `issue` + 4 skills →
      `feat/lifecycle-commands-and-skills`
- [x] **PR B** — inquiry: removal of the six catalog items → `refactor/remove-lifecycle-commands`
- [x] **PR C** — macss: `project` module (`check` / `adopt`), extended `doctor`, `skill clean`
- [ ] **Docs** — macss (README, ADR 0003/0004, book) + handbook

## 14. Language policy

These are public repositories: **all new content is written in English** — code, comments, tests,
documentation, and commit messages. Content that already exists in Spanish is left untouched; the
Spanish artifact templates (`*.template.es.md`) are part of the bilingual `--lang` product contract
and are ported verbatim.
