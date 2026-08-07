# Changelog

All notable changes to this project will be documented in this file.

The format loosely follows [Keep a Changelog](https://keepachangelog.com/)
and the project adheres to [Semantic Versioning](https://semver.org/).

## [0.7.0]

A project says which language its documents are written in **once**, in
`.macss/config.yaml`, and every document derives from that. The setting used to
be a flag on each command: `requisition new --lang es`, then `specification new`
inheriting it from the requisition's `issue.yaml`, with `en` waiting as a
default wherever the chain broke. A setting passed per invocation is one that
can differ per invocation, and a project that answers differently on Tuesday
does not have an answer. ADR 0009 — a default may derive, but never invent — is
what this release applies to language.

### Added
- **`macss requisition list`** — every requisition in the project, with the
  active one marked, how far each has got, and the issue carrying it. Until now
  the only way to see what existed was to list `docs/requisitions/` and read
  folder names, which said nothing else.

  It reads what is on disk and does not run the stage gates: a row says "has a
  contract", not "the contract passes". Running three gates per row would be
  slow and could fail for reasons that have nothing to do with listing. It also
  shows a pointer aimed at a folder that is gone, rather than omitting it — a
  listing that hides a broken state is how it becomes trusted and wrong.

- **`macss requisition activate <slug>`** — choose the requisition the following
  commands act on. This was a hand edit of `.macss/state.yaml`, keeping two keys
  consistent with each other and with a folder name, checked by nothing. It was
  the only unguarded operation in a CLI that will not even choose between
  `--plan` and `--apply` for you, and it now follows that convention like
  everything else that writes.

  The name comes from the vocabulary already in the code: the pointer records
  the **active** requisition. `set` would not say what is being set, and git's
  `checkout` carries a meaning that does not apply.

### Changed — BREAKING
- **`--lang` is gone from `requisition new` and `specification new`.** Both
  derive the language from `.macss/config.yaml`. Scripts passing the flag will
  fail with `unknown option --lang`; the language moves to the project, once.

  `specification new` also stops inheriting from the requisition's `issue.yaml`.
  Inheriting was the right instinct applied one hop at a time — it made the
  requisition an authority on a question that was never its own, and left the
  answer to be re-derived at every hop.

  Neither `issue.yaml` nor `.macss/state.yaml` carries a `lang:` key any more.
  A copy of the declaration is a second answer waiting to disagree with the
  first, and two answers is none. Existing files keep the key; nothing reads it.

- **`project create` and `project adopt` require `--lang <en|es>`.** A project
  declares the language of its documents at the moment that choice is made, by
  the person making it. There is no default: English is not a neutral choice,
  it is a guess about who will read the documents.

- **`specification export-template` is removed.** Of the two documents, only the
  requisition is handed to somebody outside the team — it is this method's issue
  template, and a Product Owner may prefer filling one directly. The contract is
  written by whoever holds the pen, on top of a request that already exists; a
  blank one is a form for work nobody outside is doing.

  `requisition export-template` survives **and is the one command that still
  takes `--lang`, now required**: it writes at a path that need not be a MACSS
  project, so there is nothing to derive from. Not an exception to the rule —
  the reason the rule has one.

- **A project that has not declared a language is stopped, not assumed to be
  English.** `requisition new` and `specification new` refuse and name the way
  out: `macss project adopt --lang <en|es> --apply`. **This includes every
  project created before this release**, the MACSS repository itself among them.
  Adopting is a one-line change and the command reports it in its plan first.

- **An ambiguous `--slug` is refused instead of resolved.** Two requisitions can
  answer to one slug: the date prefix makes folder *names* unique, not slugs.
  The resolver used to sort the matches and return the newest, silently. That is
  a default that invents a decision, which ADR 0009 forbids.

  It now resolves to nothing and the command reports both candidates. This
  reaches **every command that takes `--slug`** — `requisition check`,
  `requisition publish`, `specification new`, `specification check`,
  `specification publish` and `dor check` — none of which this change is named
  after. Where they used to proceed on a guess, they now refuse and name the
  candidates.

  A test asserted the old behaviour explicitly: *"multiple dated matches →
  newest (lexically last) wins"*. The suite was defending the defect, which is
  the second time that has happened in this cycle.

- **`.macss/` now ignores itself, and the project root stops hiding it.** A
  `--plan` in a project that had never opened a requisition created the
  workspace with nothing ignoring it: only `requisition new` knew about the
  ignore rule. The rule now lives inside the directory it governs, written
  wherever the workspace is created, so both paths into it — the active-
  requisition pointer and the plan files — find it already ignoring itself.

  It is an **allowlist**: everything ignored, exceptions named. The two designs
  fail differently. A denylist forgets in silence — anything MACSS invents there
  later is committed until somebody remembers to add it. An allowlist forgets in
  the open: somebody clones, a file is missing, it is noticed. `!.gitignore` is
  part of it, or the file that makes every other rule work is never committed.

  **`.macss/` is removed from the project root's `.gitignore`**, and `project
  adopt` retires it from projects that already carry it. That is not tidying:
  git does not descend into an excluded directory, so while the root excluded
  `.macss/` the inner rule was dead letter and nothing there could ever be
  versioned. Verified against real git rather than by reading the file back.

  **`adopt` removes something for the first time.** ADR 0004 said it never
  deletes, and that stands for anything the project wrote — the licence here is
  the one `skill deploy` already uses to prune its own namespace: an entry under
  the MACSS header is machine-written output, not a user edit. Nothing outside
  that header is touched, and the retirement appears in the plan like every
  other change.

### Changed
- **An incomplete invocation now says so, instead of claiming the command does
  not exist.** `macss project` answered `unknown command 'project'` followed by
  the whole catalogue; the name was real, and what was missing was the action.
  It now names the completions and only those:

  ```
  ❯ macss project
  Error: 'project' is not a complete command.

  Commands:
    project create  Scaffold a new MACSS project
    project check   Diagnose a project against the MACSS canon …
  ```

  The fix is `modular_cli_sdk` 0.3.4 and the constraint moves with it. Nothing
  in this CLI changed: the SDK asks its catalogue whether what was typed
  continues into a registered route, which also covers `macss api graphql` —
  not a module, but the first segment of `api graphql compile`.

## [0.6.0]

A breaking release on a minor bump: the project is still in the `0.x` series,
where the leading zero is the signal that the interface is not yet settled.

ADR 0004 named a `--plan` / `--apply` convention. Only `--apply` was ever built,
with the absence of it standing in for the plan — so `project check`, the
specification skill and the book all dictated `macss … --plan`, and every one of
those invocations failed with `unknown option --plan`. The documents were right
about what MACSS wanted; the binary had never caught up. ADR 0007 supersedes the
old convention and this release implements it.

### Changed — BREAKING
- **Every command that changes state now requires `--plan` or `--apply`.**
  Neither is a default and a bare invocation is a usage error. That covers
  `project create`, `project adopt`, `requisition new`,
  `requisition export-template`, `requisition publish`, `specification new`,
  `specification export-template`, `specification publish`, `skill deploy`,
  `skill clean`, `api graphql compile`, `upgrade` and `uninstall`. Read-only
  commands — `check` in every module, `doctor`, `version`, `dor check`,
  `skill list` — take neither and reject both.

  Previously the absence of `--apply` meant "preview". That made not-writing the
  outcome of forgetting a flag, so the safe path and the writing path were told
  apart by an omission and the invocation recorded neither. Every bare
  `macss project adopt` and `macss requisition publish` in a script will now
  fail, loudly and with the two ways out named.

- **`--plan` writes a plan file** under `.macss/plans/`, rather than printing a
  preview that dies with the terminal. A plan can be attached to an issue,
  diffed against a later run, or read by someone who was not at the keyboard —
  which is what MACSS asks of every other artifact it produces. Plans are
  written where the command was **invoked**, never inside the directory it
  targets: writing into the target would itself be a change, and for
  `project create` the target is what the command would bring into existence.

- **`--apply` shows the plan and asks before writing.** Declining changes
  nothing and exits non-zero. The plan it shows and the plan `--plan` writes are
  the same computation rendered once, so they cannot drift.

- **`--apply --autoapprove` applies without asking**, for agents and CI. When
  `--apply` finds no terminal to ask from it refuses and names the flag, rather
  than blocking on a read that will never return. `--yes` was rejected as the
  name: it answers a prompt without saying what is being agreed to, and the flag
  is not about the prompt — it transfers the approval from a human at the
  keyboard to whoever wrote the invocation.

- **The banner's quickstart now reads `macss project create --path=my-project
  --apply`.** A newcomer's first command is where the convention is learned.

### Changed
- **The specification skill instructs `--apply --autoapprove`** wherever it
  applies changes. A skill runs with nobody at the keyboard; a bare `--apply`
  would strand it on a prompt.

- **The guard on skills now checks flags, not just commands.** It stripped them,
  and the comment explaining why used `macss requisition publish --plan` as its
  example — the exact invocation that was broken. It passed for two releases
  over a skill telling models to type a flag the CLI rejected. It now also fails
  a skill that names `--apply` without `--autoapprove`.

- **The analyst may fill the requisition; the Product Owner remains its
  author.** The methodology said "Do not fill it for him", and the request
  arrives by email or in a meeting from someone who will not then sit down to a
  form — so the rule was broken on every requisition, including the ones that
  produced this release. It is replaced by what it was actually protecting:
  transcribe what he said, trace every line to a source, and ask him rather than
  filling a gap yourself. The `requisition` module's descriptions and messages
  no longer assume the form is handed over to be typed by him, and its gate is
  stated as what it always checked — whether every section is answered, not who
  answered it.

### Fixed
- **Approval no longer crashes where a terminal is claimed but unreadable.**
  `--apply` with stdout piped exited 255 with `StdinException: Error getting
  terminal line mode` on Windows: `stdin.hasTerminal` reported a terminal and
  the read then failed. Anything that stops an answer from arriving now produces
  the same refusal, so a command that changed nothing cannot present itself as a
  crash.

- **Republishing an issue no longer fails when the requisition declares
  labels.** `publish` sent `--label` to both `gh issue create` and `gh issue
  edit`, but only `create` accepts it — `edit` takes `--add-label`. The create
  path worked, so the break only surfaced on the second publish, which is
  exactly when `specification publish` adds the contract to the issue. `edit`
  now uses `--add-label`, which also leaves labels added by hand on GitHub
  alone. Nothing covered `plannedArgs`; both label paths are now tested.

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
- The same guard for the **banner**, which is hand-maintained and advertised
  `issue` until someone edited it by hand. Every command it names must be a
  route the CLI serves, and it must name every lifecycle stage.

### Fixed
- `project_create_test` registered its own root-level `create` route rather than
  the module that ships. It exercised a contract no user could reach.
- `tui_test` asserted the banner `contains('create')`, which passed on the word
  appearing in the Quickstart line rather than on any advertised command — and
  kept passing after `create` was gone.

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
