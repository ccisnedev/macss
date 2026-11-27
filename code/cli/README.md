# macss CLI

The `macss` command line. Dart, compiled to a single executable that ships with
its `assets/` folder.

## Development build

Assets are resolved relative to the executable: two directories above it, in
`assets/`. So the CLI only gives correct answers when it runs as a compiled
binary with its assets beside it.

**`dart run bin/main.dart` does not resolve the assets.** The running
executable is then the Dart VM, so the assets are looked up inside the Dart SDK.
The CLI refuses to run that way (exit 78) and points here.

Build and run the dev build from `code/cli`:

```
scripts/build.ps1        # Windows (PowerShell)
scripts/build.sh         # Linux and macOS

dist/bin/macss doctor    # dist/bin/macss.exe on Windows
```

`dist/` holds the compiled binary and a copy of `assets/`, and nothing else.
It is git-ignored and entirely separate from any installed `macss`: nothing
under `scripts/` writes to the installation directory. Each build wipes `dist/`
first, so a file removed from `assets/` does not survive in the dev build, and
`doctor` reports on what the source ships today.

## Tests

```
dart test
dart analyze --fatal-infos
```
