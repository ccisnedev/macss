# Changelog

All notable changes to this project will be documented in this file.

The format loosely follows [Keep a Changelog](https://keepachangelog.com/)
and the project adheres to [Semantic Versioning](https://semver.org/).

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
