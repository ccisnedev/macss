/// `macss skill clean [--path <dir>] [--host <assistant>]` — removes skills this
/// CLI deployed.
///
/// Only skills MACSS ships are removed, by name. Anything else living in the
/// target directory is another tool's, or the user's, and is left alone.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../assets.dart';
import '../host.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class SkillCleanInput extends Input {
  final String resolvedPath;
  final String? host;

  SkillCleanInput({required this.resolvedPath, this.host});

  factory SkillCleanInput.fromCliRequest(CliRequest req) {
    final rawPath = req.flagString('path', aliases: const ['p']);
    final workingDirectory = Directory.current.path;
    final resolved = rawPath == null
        ? workingDirectory
        : (p.isAbsolute(rawPath) ? rawPath : p.join(workingDirectory, rawPath));

    return SkillCleanInput(
      resolvedPath: resolved,
      host: req.flagString('host'),
    );
  }

  static final List<CliParam> params = [
    CliParam.string(
      'path',
      abbr: 'p',
      description: 'Project directory to remove the skills from',
    ),
    CliParam.string(
      'host',
      allowed: supportedHosts,
      description: 'Also remove them from this assistant\'s skills directory',
    ),
  ];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {'resolvedPath': resolvedPath, 'host': host};
}

// ─── Output ─────────────────────────────────────────────────────────────────

class SkillCleanOutput extends Output {
  final String message;
  final List<String> removed;
  final int _exitCode;

  SkillCleanOutput({
    required this.message,
    this.removed = const [],
    int exitCode = ExitCode.ok,
  }) : _exitCode = exitCode;

  @override
  Map<String, dynamic> toJson() => {'message': message, 'removed': removed};

  @override
  int get exitCode => _exitCode;

  @override
  String? toText() => message;
}

// ─── Command ────────────────────────────────────────────────────────────────

class SkillCleanCommand implements Command<SkillCleanInput, SkillCleanOutput> {
  @override
  final SkillCleanInput input;

  final Assets assets;
  final Map<String, String>? environment;

  SkillCleanCommand(this.input, {required this.assets, this.environment});

  @override
  String? validate() {
    if (!assets.directoryExists('skills')) {
      return 'No skills found in the installed assets. Run: macss upgrade';
    }
    return null;
  }

  @override
  Future<SkillCleanOutput> execute() async {
    final names = assets.listDirectory('skills');

    final targets = <String, String>{
      p.join(input.resolvedPath, '.skills'): '.skills',
    };

    if (input.host != null) {
      final dir = hostSkillsDirectory(input.host!, environment: environment);
      if (dir == null) {
        return SkillCleanOutput(
          message: 'Cannot resolve the home directory for host '
              '"${input.host}". Set HOME or USERPROFILE.',
          exitCode: ExitCode.genericError,
        );
      }
      targets[dir] = dir;
    }

    final steps = <String>[];
    final removed = <String>[];

    for (final entry in targets.entries) {
      for (final name in names) {
        final dir = Directory(p.join(entry.key, name));
        final display = p.posix.join(entry.value, name);
        if (dir.existsSync()) {
          dir.deleteSync(recursive: true);
          steps.add('removed  $display');
          removed.add(name);
        } else {
          steps.add('absent   $display');
        }
      }
    }

    return SkillCleanOutput(
      message: steps.join('\n'),
      removed: removed.toSet().toList()..sort(),
    );
  }
}
