# Changelog

All notable changes to this project will be documented in this file.

The format loosely follows [Keep a Changelog](https://keepachangelog.com/)
and the project adheres to [Semantic Versioning](https://semver.org/).

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
- `macss skill deploy` materializes the four lifecycle skills
  (`macss-specification`, `macss-analyze`, `macss-plan`, `macss-execute`) into a
  project-local, git-ignored `.skills/` directory, readable by any assistant.
  `--host claude|opencode` also deploys to that assistant's own location.
  `macss skill list` and `macss skill clean` complete the module.
- `Assets.listDirectory()`, sorted so deployment order is identical on every
  platform.

### Changed
- `macss create` now deploys the lifecycle skills into `.skills/`, and the
  scaffolded `.gitignore` ignores `.macss/`, `.skills/`, and
  `docs/requisitions/`.
- `macss doctor` verifies the artifact templates and the shipped skills, not just
  the project templates.
- Unlike `create`, `skill deploy` refreshes a skill whose content changed:
  `.skills/` is reproducible machine output, so a stale file left behind by an
  older CLI is a defect, not a user edit.

### Migration
- The active-requisition pointer moved from `.inquiry/specification.yaml` to
  `.macss/specification.yaml`. If you have a requisition in flight, move that
  file by hand.
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
