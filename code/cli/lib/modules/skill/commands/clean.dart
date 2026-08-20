/// `macss skill clean [--host <assistant>] --plan|--apply` — removes the
/// lifecycle skills from the assistants they were deployed to.
///
/// Only skills MACSS ships are removed, by name. Anything else living in the
/// assistant's skills directory is another tool's, or the user's, and is left
/// alone.
///
/// The only command in the CLI whose whole purpose is to delete, which is why
/// naming every directory it would remove — before removing any — is the least
/// the convention is for. It used to name them by walking the hosts once to
/// build the preview and again to do the work, two loops written out character
/// for character. Now the walk happens once, and produces the steps.
library;

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../assets.dart';
import '../deployer.dart';
import '../host.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class SkillCleanInput extends Input {
  SkillCleanInput({this.host});

  final String? host;

  factory SkillCleanInput.fromCliRequest(CliRequest req) =>
      SkillCleanInput(host: req.flagString('host'));

  static final List<CliParam> params = [
    CliParam.string(
      'host',
      allowed: supportedHosts,
      description: 'Clean this assistant only; defaults to every one installed',
    ),
  ];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {'host': host};
}

// ─── Output ─────────────────────────────────────────────────────────────────

class SkillCleanOutput extends Output {
  SkillCleanOutput({required this.removed, required this.absent});

  /// The skills that were there and are not any more.
  final List<String> removed;

  /// The skills that were already gone. Reported rather than omitted: a clean
  /// that says nothing about what it did not find reads as if it found nothing.
  final List<String> absent;

  @override
  Map<String, dynamic> toJson() => {'removed': removed, 'absent': absent};

  @override
  int get exitCode => ExitCode.ok;

  @override
  String? toText() => removed.isEmpty && absent.isEmpty
      ? 'No supported assistant found in your home directory.'
      : [
          ...removed.map((s) => '  removed  $s'),
          ...absent.map((s) => '  absent   $s'),
        ].join('\n');
}

// ─── Command ────────────────────────────────────────────────────────────────

class SkillCleanCommand
    implements Command<SkillCleanInput, SkillCleanOutput>, ExplainsNothingToDo {
  /// Nothing installed means nothing to clean, and the caller is better served
  /// by being told which situation they are in than by `nothing would change`.
  @override
  String? get nothingToDo => 'No supported assistant found in your home directory.';

  SkillCleanCommand(this.input, {required this.assets, this.environment});

  @override
  final SkillCleanInput input;

  final Assets assets;
  final Map<String, String>? environment;

  @override
  String? validate() => null;

  @override
  Future<List<Step>> steps() async {
    final hosts = input.host != null
        ? [input.host!]
        : detectHosts(environment: environment);

    // Nothing installed means nothing to clean, and that is not a failure: the
    // state the caller asked for already holds. So no steps rather than an
    // error — `deploy` refuses in the same situation because there the caller
    // asked for something to happen and nothing did.
    if (hosts.isEmpty) return const [];

    final names = assets.listDirectory('skills');

    return [
      for (final host in hosts)
        for (final name in names)
          RemoveSkill(
            directory: p.join(_pathsFor(host).skillsDirectory, name),
          ),
    ];
  }

  HostPaths _pathsFor(String host) {
    final paths = hostPaths(host, environment: environment);
    if (paths == null) {
      throw CommandException(
        code: 'HOME_NOT_RESOLVED',
        message:
            'Cannot resolve the home directory for host "$host". '
            'Set HOME or USERPROFILE.',
        exitCode: ExitCode.genericError,
      );
    }
    return paths;
  }

  @override
  SkillCleanOutput describe(Execution execution) => SkillCleanOutput(
    removed: [
      for (final o in execution.outcomes)
        if (o.verb == 'remove') p.basename(o.target),
    ],
    absent: [
      for (final o in execution.outcomes)
        if (o.verb == 'absent') p.basename(o.target),
    ],
  );
}
