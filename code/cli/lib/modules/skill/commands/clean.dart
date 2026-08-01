/// `macss skill clean [--host <assistant>]` — removes the lifecycle skills from
/// the assistants they were deployed to.
///
/// Only skills MACSS ships are removed, by name. Anything else living in the
/// assistant's skills directory is another tool's, or the user's, and is left
/// alone.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../assets.dart';
import '../host.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class SkillCleanInput extends Input {
  final String? host;

  SkillCleanInput({this.host});

  factory SkillCleanInput.fromCliRequest(CliRequest req) =>
      SkillCleanInput(host: req.flagString('host'));

  static final List<CliParam> params = [
    CliParam.string(
      'host',
      allowed: supportedHosts,
      description:
          'Clean this assistant only; defaults to every one installed',
    ),
  ];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {'host': host};
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
    final hosts = input.host != null
        ? [input.host!]
        : detectHosts(environment: environment);

    if (hosts.isEmpty) {
      return SkillCleanOutput(
        message: 'No supported assistant found in your home directory.',
      );
    }

    final names = assets.listDirectory('skills');
    final steps = <String>[];
    final removed = <String>[];

    for (final host in hosts) {
      final paths = hostPaths(host, environment: environment);
      if (paths == null) {
        return SkillCleanOutput(
          message: 'Cannot resolve the home directory for host "$host". '
              'Set HOME or USERPROFILE.',
          exitCode: ExitCode.genericError,
        );
      }

      steps.add('$host → ${paths.skillsDirectory}');
      for (final name in names) {
        final dir = Directory(p.join(paths.skillsDirectory, name));
        if (dir.existsSync()) {
          dir.deleteSync(recursive: true);
          steps.add('  removed  $name');
          removed.add(name);
        } else {
          steps.add('  absent   $name');
        }
      }
    }

    return SkillCleanOutput(
      message: steps.join('\n'),
      removed: removed.toSet().toList()..sort(),
    );
  }
}
