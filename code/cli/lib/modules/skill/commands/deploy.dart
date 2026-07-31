/// `macss skill deploy [--host <assistant>]` — installs the lifecycle skills the
/// CLI ships into the assistant's own skills directory under the user's home.
///
/// With no `--host`, every supported assistant that is installed on this machine
/// is refreshed. With `--host`, only that one, whether or not it looks installed
/// — so a fresh setup can be primed before the assistant first runs.
///
/// This is a per-machine operation, done rarely. Deploying into a repository
/// would mean repeating it in every clone.
///
/// Unlike `macss create`, this command **refreshes** a skill whose content has
/// changed: the deployed copy is machine-written output reproducible from the
/// shipped assets, so a stale file left by an older CLI is a defect rather than
/// a user edit worth preserving.
library;

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import '../../../assets.dart';
import '../deployer.dart';
import '../host.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class SkillDeployInput extends Input {
  final String? host;

  SkillDeployInput({this.host});

  factory SkillDeployInput.fromCliRequest(CliRequest req) =>
      SkillDeployInput(host: req.flagString('host'));

  /// Declared contract: a single optional `--host`. Omitting it deploys to every
  /// installed assistant, which is the common case.
  static final List<CliParam> params = [
    CliParam.string(
      'host',
      allowed: supportedHosts,
      description:
          'Deploy to this assistant only; defaults to every one installed',
    ),
  ];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {'host': host};
}

// ─── Output ─────────────────────────────────────────────────────────────────

class SkillDeployOutput extends Output {
  final String message;
  final List<String> hosts;
  final int _exitCode;

  SkillDeployOutput({
    required this.message,
    this.hosts = const [],
    int exitCode = ExitCode.ok,
  }) : _exitCode = exitCode;

  @override
  Map<String, dynamic> toJson() => {'message': message, 'hosts': hosts};

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
    if (!assets.directoryExists('skills')) {
      return 'No skills found in the installed assets. Run: macss upgrade';
    }
    return null;
  }

  @override
  Future<SkillDeployOutput> execute() async {
    final hosts = input.host != null
        ? [input.host!]
        : detectHosts(environment: environment);

    if (hosts.isEmpty) {
      return SkillDeployOutput(
        message: 'No supported assistant found in your home directory.\n'
            'Supported: ${supportedHosts.join(', ')}.\n'
            'Pass --host <assistant> to deploy anyway.',
        exitCode: ExitCode.notFound,
      );
    }

    final steps = <String>[];
    for (final host in hosts) {
      final paths = hostPaths(host, environment: environment);
      if (paths == null) {
        return SkillDeployOutput(
          message: 'Cannot resolve the home directory for host "$host". '
              'Set HOME or USERPROFILE.',
          exitCode: ExitCode.genericError,
        );
      }
      steps.add('$host → ${paths.skillsDirectory}');
      steps.addAll(
        deploySkills(assets: assets, targetDir: paths.skillsDirectory),
      );
    }

    return SkillDeployOutput(message: steps.join('\n'), hosts: hosts);
  }
}
