# Changelog

All notable changes to this project will be documented in this file.

The format loosely follows [Keep a Changelog](https://keepachangelog.com/)
and the project adheres to [Semantic Versioning](https://semver.org/).

## [0.5.0]

The skills are what a model actually executes. They had drifted from the CLI —
`macss-specification` was instructing `macss issue new` and `macss issue
publish`, removed in 0.4.0 — and nothing in the suite connected the two.

### Changed — BREAKING
- **`macss create` is removed.** It shipped deprecated in 0.3.0 as an alias of
  `macss project create`. Two names for one command left the grammar ambiguous
  about which noun owns scaffolding, which is the one thing `project` exists to
  settle.

### Changed
- **`macss-specification` is rewritten** for the one-to-one model. It now walks
  the whole stage — `requisition new` through `dor check` — instead of the
  middle of it, and states the two rules the commands cannot enforce: the
  Product Owner writes his own request, and the issue body freezes at DoR.
- **`macss-analyze` and `macss-plan` publish their output on the issue.** The
  diagnosis and the plan used to live in the model's session, which ends. They
  are now comments below the frozen body: the body is what was agreed, the
  comments are how the work unfolded.
- **`macss-execute` closes the chain** by opening the PR against the issue that
  carries the request, the contract, the diagnosis and the plan.

### Added
- **`skill_commands_test`**: every `macss <…>` a skill names is cross-checked
  against `help --json`, the CLI's own catalogue. A skill that instructs a
  command the CLI does not accept now fails the suite — the drift guard
  `help_command_test` gives the catalogue, aimed at the skills.

### Fixed
- `project_create_test` registered its own root-level `create` route rather than
  the module that ships. It exercised a contract no user could reach.

## [0.4.0]

The CLI now follows the model the methodology actually uses: **one requirement
is one issue**, and the issue is where the request and its contract persist.

### Changed — BREAKING
- **`macss requisition`** is the new stage module: `export-template` writes the
  blank form for the Product Owner, `new` opens the requisition, `check` asks
  whether he filled it, and `publish` creates the issue carrying the request.
- **`macss specification new` creates only `specification.md`**, and requires an
  open requisition. It used to create both documents, which collapsed a real
  distinction: the requisition is a form the business fills, the specification
  is QA's contract — different authors, different moments.
- **`macss specification publish`** adds the contract to the issue the
  requisition created, so the body reads request first, contract second.
- **`macss issue new` and `macss issue publish` are removed.** The issue body is
  assembled from the two documents rather than hand-authored, which is what
  made a third document — repeating their context and scope — unnecessary.
- **`.macss/specification.yaml` → `.macss/state.yaml`.** It records which
  requisition is active; the old name said something else.

### Added
- **`macss dor check`** — the Definition of Ready. It composes the stage checks
  and adds what neither owns: that the requirement has a home. Until the issue
  exists there is nothing to pick up, reference from a branch, or freeze.
- The requisition asks for **value**: what problem this solves, who it affects,
  what happens if it is not done. Three questions, one sentence each, all of
  them facts only the requester has. The fourth — how we will know it worked —
  lands in the specification, because turning value into something observable
  is analysis, not form-filling.
- **`assets/vocabulary/<lang>.yaml`.** The gate's keywords are assets now, so
  adding a language is one file plus its templates: no code change, and no new
  tests, because the suite enumerates the directory.

### Removed
- `SPEC_NO_ISSUE` and `SPEC_AC_NOT_TRACED`. Both were artefacts of
  one-specification-many-issues. Under one-requirement-one-issue they are
  tautologies: the document *is* the issue, and every acceptance criterion in it
  is covered by definition.
- `covers:` and `spec:` from the issue front-matter, and `repo` from the issue
  metadata — `gh` infers the repository from the directory, the way `gh pr list`
  does.

### Fixed
- The Spanish specification template no longer embeds English
  (`**As a (Como)**`). A Product Owner reading a Spanish form saw two languages
  mixed for no reason he could see.

## [0.3.2]

### Fixed
- **The banner's Quickstart advertised a command that fails.** It printed
  `macss create my-project` — a positional argument the CLI rejects (ADR 0002
  chose explicit flags), on the alias deprecated in 0.3.0. The first command a
  new user was told to run exited 7. It is now
  `macss project create --path=my-project`.

  The guard that should have caught it asserted the banner *contained* the
  string `macss create`, which a broken command satisfies. The test now runs
  the advertised command through the CLI and asserts it scaffolds a project,
  so a quickstart that stops working fails the build.

## [0.3.1]

### Fixed
- **`macss skill deploy` could add but never retire.** A skill dropped from a
  release survived in the host forever as a frozen copy nothing would ever
  update again. Deploy now removes skills in the `macss-` namespace that MACSS
  no longer ships, reporting each one.

  Scoped by prefix rather than a hand-maintained list of retirements: the
  `macss-` namespace is ours, so anything under it we do not ship is ours to
  remove — self-maintaining for any future rename or drop. Everything else in
  the directory is left alone, including another tool's skills.

## [0.3.0]

The lifecycle stages have a module surface, and the canon has a verifier.

### Added
- **`macss project`** — a project's conformance to the canon, at three moments.
  `project create` scaffolds one, `project check` diagnoses an existing one, and
  `project adopt` retrofits a project that predates MACSS (`--plan` previews,
  `--apply` writes). All three share one definition of the canon, so they cannot
  disagree about what a MACSS project is.
- `macss doctor` gains an external toolchain preflight: `git`, `gh`, `pwsh`,
  `dotnet`, `sqlpackage`, `docker`, `flutter` — each with what it is needed for
  and how to install it. Presence is a PATH lookup, so `doctor` stays instant.
- A third check status, `warning`, for what needs human judgement rather than a
  fix. It never fails a command.
- `CHANGELOG.md` is now part of the scaffold. The canon in
  `code/book/src/project-structure.md` always required it; `create` never
  produced it, and nothing detected the gap.

### Changed
- **`macss create` is deprecated** in favour of `macss project create`. It keeps
  working for one minor version. `create` is the entry point to the whole
  methodology but was a bare root-level command; the CLI grammar reserves
  modules for nouns and verbs for leaf actions, so it belongs under `project`
  beside the commands that verify what it stamps.
- The implementation skills — `macss-analyze`, `macss-plan`, `macss-execute` —
  are self-contained. They previously opened by invoking `iq`, which gave MACSS
  a runtime dependency on a second CLI. They now teach the method on their own,
  sourced from the engineering handbook.

## [0.2.0]

MACSS now owns the software lifecycle it defines. The specification and issue
stages, plus the skills for every stage, move here from the `inquiry` CLI, which
goes back to being the state machine for the implementation stage alone.

### Added
- `macss specification new <slug>` scaffolds a requisition workspace under
  `docs/requisitions/<YYYYMMDD>-<slug>/` and records it as the active
  requisition, so later commands need no slug. `--lang en|es`.
- `macss specification check` runs the `specification_ready` gate over the active
  requisition.
- `macss issue new <name>` scaffolds an "issue as code" file, inheriting the
  specification's language; `macss issue publish <name>` turns it into a GitHub
  issue via `gh`, previewing with `--plan` before `--apply`.
- `macss skill deploy` installs the four lifecycle skills
  (`macss-specification`, `macss-analyze`, `macss-plan`, `macss-execute`) into
  the skills directory of every supported assistant found in your home
  directory. `--host claude|opencode` targets one, whether or not it looks
  installed, so a fresh setup can be primed. Skills are installed once per
  machine, not per repository. `macss skill list` and `macss skill clean`
  complete the module.
- `Assets.listDirectory()`, sorted so deployment order is identical on every
  platform.

### Changed
- The scaffolded `.gitignore` now ignores `.macss/` and `docs/requisitions/`.
- `macss doctor` verifies the artifact templates and the shipped skills, not just
  the project templates.
- Unlike `create`, `skill deploy` refreshes a skill whose content changed:
  `.skills/` is reproducible machine output, so a stale file left behind by an
  older CLI is a defect, not a user edit.

### Migration
- The active-requisition pointer moved from `.inquiry/specification.yaml` to
  `.macss/specification.yaml`. A requisition in flight still works without any
  manual step — pass `--slug <slug>`, which resolves the folder directly and
  ignores the pointer. Move the file only to restore the convenience of an
  active requisition that the commands pick up on their own.
- The on-disk format tokens are now namespaced to MACSS: templates emit
  `macss:lang` and `kind: macss-issue`. Specifications already written with
  `iq:lang` keep resolving their language, so existing requisitions still work.

## [0.1.0]

### Changed
- Migrated the CLI to `modular_cli_sdk` 0.3.3 and `cli_router` 0.1.0.
- Every command declares its parameter contract, so unknown flags are rejected
  (exit 7) instead of being silently ignored.
- Help is rendered from the command catalog by the SDK; the hand-written `help`
  command was removed so help can no longer drift from the registered commands.
  `<command> --help` shows the command's declared contract.
- `macss create` now scaffolds `code/{db,api,app,infra}` with a README anchor per
  module — the presentation layer is `app` (renamed from `ui`) — so the structure
  survives the first commit and each module documents its allowed dependencies.
- `modular_api` and `modular_api_sqlserver` are consumed from published pub.dev
  versions instead of local paths.

### Removed
- Dead GraphQL compile help path (`helpRequested` flag and hand-written help
  text), superseded by the SDK-rendered contract.

## [0.0.3]

### Added
- `macss create` now generates `README.md` from template
- `macss create` now generates `.gitignore` with common exclusions
- `macss create` now generates `.gitattributes` for cross-platform line endings (LF default)

## [0.0.2]

### Changed
- `macss create` now uses `--path` flag instead of positional argument
  - Usage: `macss create --path=.` or `macss create -p <dir>`

## [0.0.1]

### Added
- `macss` — TUI banner with version, commands and alias
- `macss create <path>` — scaffold MACSS project structure from templates
- `macss doctor` — verify local installation and assets integrity
- `macss upgrade` — download and install latest release from GitHub Releases
- `macss uninstall` — remove MACSS CLI from the system
- `macss version` — print current CLI version
- CI matrix (Windows + Linux)
- Release workflow with binary + assets packaging
