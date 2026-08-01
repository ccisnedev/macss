/// External tools MACSS commands shell out to, and how to find them.
///
/// Presence is decided by a PATH lookup rather than by running each tool: some
/// of them take seconds to answer `--version`, and `macss doctor` is meant to be
/// instant. Whether a tool *works* is the tool's own business; whether it is
/// installed is what a preflight can usefully answer.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// An executable a MACSS command depends on.
class ExternalTool {
  final String executable;

  /// What stops working without it — shown so a missing tool is actionable
  /// rather than a bare complaint.
  final String neededFor;

  /// How to install it.
  final String install;

  const ExternalTool({
    required this.executable,
    required this.neededFor,
    required this.install,
  });
}

/// The tools MACSS itself invokes, plus the deploy toolchain the roadmap
/// delegates to `macss-devops`.
///
/// None of these is required for the CLI to be sound, so a missing one is a
/// warning: it narrows what you can do, it does not break what you have.
const externalTools = <ExternalTool>[
  ExternalTool(
    executable: 'git',
    neededFor: 'version control across every stage',
    install: 'https://git-scm.com/downloads',
  ),
  ExternalTool(
    executable: 'gh',
    neededFor: 'macss issue publish',
    install: 'winget install GitHub.cli — or: brew install gh',
  ),
  ExternalTool(
    executable: 'pwsh',
    neededFor: 'macss-devops, the deploy toolchain',
    install: 'winget install Microsoft.PowerShell — or: brew install powershell',
  ),
  ExternalTool(
    executable: 'dotnet',
    neededFor: 'sqlpackage, for database publishing',
    install: 'https://dotnet.microsoft.com/download',
  ),
  ExternalTool(
    executable: 'sqlpackage',
    neededFor: 'publishing the database dacpac',
    install: 'dotnet tool install -g microsoft.sqlpackage',
  ),
  ExternalTool(
    executable: 'docker',
    neededFor: 'containerized infrastructure and disposable databases',
    install: 'https://docs.docker.com/get-docker/',
  ),
  ExternalTool(
    executable: 'flutter',
    neededFor: 'building the app layer',
    install: 'https://docs.flutter.dev/get-started/install',
  ),
];

/// Whether [executable] is resolvable on `PATH`.
///
/// On Windows an executable is any of `name`, `name.exe`, `name.cmd`,
/// `name.bat` — a tool installed as a shim (`gh.cmd`) is installed.
bool isOnPath(String executable, {Map<String, String>? environment}) {
  final env = environment ?? Platform.environment;
  final pathVar = env['PATH'] ?? env['Path'] ?? '';
  if (pathVar.isEmpty) return false;

  final separator = Platform.isWindows ? ';' : ':';
  final candidates = Platform.isWindows
      ? [executable, '$executable.exe', '$executable.cmd', '$executable.bat']
      : [executable];

  for (final dir in pathVar.split(separator)) {
    if (dir.isEmpty) continue;
    for (final candidate in candidates) {
      if (File(p.join(dir, candidate)).existsSync()) return true;
    }
  }
  return false;
}
