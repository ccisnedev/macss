/// `macss skill deploy [--path <dir>] [--host <assistant>]` — materializes the
/// lifecycle skills the CLI ships.
///
/// By default they land in a project-local, git-ignored `.skills/` directory.
/// That is not a standard any assistant auto-detects, but it is readable by all
/// of them — which beats deploying per assistant as the list of assistants
/// grows. `--host` opts into an assistant's own location for auto-detection.
///
/// Unlike `macss create`, this command **refreshes** a skill whose content has
/// changed. `.skills/` is machine-written output reproducible from the shipped
/// assets, so a stale skill left behind by an older CLI is a defect, not a user
/// edit worth preserving.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../assets.dart';
import '../deployer.dart';
import '../host.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class SkillDeployInput extends Input {
  final String resolvedPath;
  final String? host;

  SkillDeployInput({required this.resolvedPath, this.host});

  factory SkillDeployInput.fromCliRequest(CliRequest req) {
    final rawPath = req.flagString('path', aliases: const ['p']);
    final workingDirectory = Directory.current.path;
    final resolved = rawPath == null
        ? workingDirectory
        : (p.isAbsolute(rawPath) ? rawPath : p.join(workingDirectory, rawPath));

    return SkillDeployInput(
      resolvedPath: resolved,
      host: req.flagString('host'),
    );
  }

  /// Declared contract. `--path` defaults to the working directory, so the
  /// common case is a bare `macss skill deploy`.
  static final List<CliParam> params = [
    CliParam.string(
      'path',
      abbr: 'p',
      description: 'Project directory to deploy the skills into',
    ),
    CliParam.string(
      'host',
      allowed: supportedHosts,
      description: 'Also deploy to this assistant\'s own skills directory',
    ),
  ];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {'resolvedPath': resolvedPath, 'host': host};
}

// ─── Output ─────────────────────────────────────────────────────────────────

class SkillDeployOutput extends Output {
  final String message;
  final List<String> deployed;
  final int _exitCode;

  SkillDeployOutput({
    required this.message,
    this.deployed = const [],
    int exitCode = ExitCode.ok,
  }) : _exitCode = exitCode;

  @override
  Map<String, dynamic> toJson() => {'message': message, 'deployed': deployed};

  @override
  int get exitCode => _exitCode;

  @override
  String? toText() => message;
}

// ─── Command ────────────────────────────────────────────────────────────────

class SkillDeployCommand
    implements Command<SkillDeployInput, SkillDeployOutput> {
  @override
  final SkillDeployInput input;

  final Assets assets;
  final Map<String, String>? environment;

  SkillDeployCommand(this.input, {required this.assets, this.environment});

  @override
  String? validate() {
    if (File(input.resolvedPath).existsSync()) {
      return '"${input.resolvedPath}" is an existing file, not a directory.';
    }
    if (!assets.directoryExists('skills')) {
      return 'No skills found in the installed assets. Run: macss upgrade';
    }
    return null;
  }

  @override
  Future<SkillDeployOutput> execute() async {
    final names = assets.listDirectory('skills');
    if (names.isEmpty) {
      return SkillDeployOutput(
        message: 'No skills to deploy.',
        exitCode: ExitCode.genericError,
      );
    }

    final targets = <String, String>{
      p.join(input.resolvedPath, '.skills'): '.skills',
    };

    if (input.host != null) {
      final dir = hostSkillsDirectory(input.host!, environment: environment);
      if (dir == null) {
        return SkillDeployOutput(
          message: 'Cannot resolve the home directory for host '
              '"${input.host}". Set HOME or USERPROFILE.',
          exitCode: ExitCode.genericError,
        );
      }
      targets[dir] = dir;
    }

    final steps = <String>[];
    for (final entry in targets.entries) {
      steps.addAll(
        deploySkills(
          assets: assets,
          targetDir: entry.key,
          display: entry.value,
        ),
      );
    }

    return SkillDeployOutput(
      message: steps.join('\n'),
      deployed: names.toSet().toList()..sort(),
    );
  }
}
