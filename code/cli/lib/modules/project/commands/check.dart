/// `macss project check [--path <dir>]` — read-only diagnosis of a project
/// against the MACSS canon.
///
/// Answers two questions a scaffolder cannot: what is **missing** from a project
/// that should follow the canon, and what is **extra or deviating** in one that
/// mostly does. Missing files are errors, because `project adopt` can create
/// them. Deviations are warnings, because they need human judgement.
///
/// This command never writes anything.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../src/checks.dart';
import '../canon.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class ProjectCheckInput extends Input {
  final String resolvedPath;

  ProjectCheckInput({required this.resolvedPath});

  factory ProjectCheckInput.fromCliRequest(CliRequest req) {
    final raw = req.flagString('path', aliases: const ['p']);
    final cwd = Directory.current.path;
    return ProjectCheckInput(
      resolvedPath:
          raw == null ? cwd : (p.isAbsolute(raw) ? raw : p.join(cwd, raw)),
    );
  }

  /// `--path` defaults to the working directory, so the common case is a bare
  /// `macss project check` inside the project.
  static final List<CliParam> params = [
    CliParam.string(
      'path',
      abbr: 'p',
      description: 'Project directory to inspect; defaults to the current one',
    ),
  ];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {'resolvedPath': resolvedPath};
}

// ─── Output ─────────────────────────────────────────────────────────────────

class ProjectCheckOutput extends Output {
  final List<DoctorCheck> checks;

  ProjectCheckOutput({required this.checks});

  int get missing =>
      checks.where((c) => c.status == CheckStatus.error).length;

  int get deviations =>
      checks.where((c) => c.status == CheckStatus.warning).length;

  @override
  Map<String, dynamic> toJson() => {
    'conforms': !hasError(checks),
    'missing': missing,
    'deviations': deviations,
    'checks': checks.map((c) => c.toJson()).toList(),
  };

  @override
  int get exitCode => hasError(checks) ? 1 : ExitCode.ok;

  @override
  String? toText() {
    final buf = StringBuffer(renderChecks(checks));
    buf.writeln();
    if (missing == 0 && deviations == 0) {
      buf.writeln('Conforms to the MACSS canon.');
    } else if (missing == 0) {
      buf.writeln(
        'Conforms to the MACSS canon. $deviations item(s) need your judgement '
        '— nothing is created or removed for them.',
      );
    } else {
      buf.writeln(
        '$missing missing, $deviations needing your judgement. '
        'Run `macss project adopt --plan` to preview what would be created.',
      );
    }
    return buf.toString();
  }
}

// ─── Command ────────────────────────────────────────────────────────────────

class ProjectCheckCommand
    implements Command<ProjectCheckInput, ProjectCheckOutput> {
  @override
  final ProjectCheckInput input;

  ProjectCheckCommand(this.input);

  @override
  String? validate() {
    if (File(input.resolvedPath).existsSync()) {
      return '"${input.resolvedPath}" is a file, not a project directory.';
    }
    if (!Directory(input.resolvedPath).existsSync()) {
      return 'No such directory: "${input.resolvedPath}".';
    }
    return null;
  }

  @override
  Future<ProjectCheckOutput> execute() async =>
      ProjectCheckOutput(checks: inspectProject(input.resolvedPath));
}
