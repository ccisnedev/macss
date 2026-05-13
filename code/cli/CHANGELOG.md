# Changelog

All notable changes to this project will be documented in this file.

The format loosely follows [Keep a Changelog](https://keepachangelog.com/)
and the project adheres to [Semantic Versioning](https://semver.org/).

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
