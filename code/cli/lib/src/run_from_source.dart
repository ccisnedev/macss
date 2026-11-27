/// Detects `dart run bin/main.dart`, which the CLI refuses.
///
/// Assets are resolved two directories above the running executable. Under the
/// Dart VM that executable is `dart`, so the path points into the SDK, every
/// asset is absent, and `doctor` reports a broken installation that is really
/// a wrong launcher (#53). The supported route is the dev build.
library;

/// Exit code for a refusal: EX_CONFIG, the one `doctor` already uses.
const int runFromSourceExitCode = 78;

/// What the refusal prints to stderr.
const String runFromSourceRefusal = '''
This CLI cannot run from source: `dart run bin/main.dart` resolves its assets
relative to the Dart VM, not to this repository.

Build the dev build from code/cli and run that instead:

  scripts/build.ps1    (Windows)
  scripts/build.sh     (Linux and macOS)

then run dist/bin/macss (dist/bin/macss.exe on Windows). It is separate from
any installed macss.
''';

/// Whether [resolvedExecutable] is the Dart VM rather than a compiled macss.
///
/// Splits on both separators so a Windows path is read correctly on any host.
bool isRunningFromSource(String resolvedExecutable) {
  final name = resolvedExecutable.split(RegExp(r'[\\/]')).last.toLowerCase();
  return name == 'dart' || name == 'dart.exe';
}
