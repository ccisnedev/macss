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

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import '../../../assets.dart';
import '../deployer.dart';
import '../host.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class SkillDeployInput extends Input {
  final String? host;
  final ChangeFlags flags;

  SkillDeployInput({this.host, this.flags = const ChangeFlags()});

  factory SkillDeployInput.fromCliRequest(CliRequest req) => SkillDeployInput(
        host: req.flagString('host'),
        flags: ChangeFlags.fromCliRequest(req),
      );

  /// Declared contract: an optional `--host`, plus the convention. Omitting
  /// `--host` deploys to every installed assistant, which is the common case.
  static final List<CliParam> params = [
    CliParam.string(
      'host',
      allowed: supportedHosts,
      description:
          'Deploy to this assistant only; defaults to every one installed',
    ),
    ...ChangeFlags.params,
  ];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {
        'host': host,
        'plan': flags.plan,
        'apply': flags.apply,
        'autoapprove': flags.autoapprove,
      };
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
  final Approver? approver;
  final DateTime Function()? now;

  /// Where the plan file goes. `skill deploy` acts on the user's home rather
  /// than on a project, so the plan belongs where the command was invoked.
  final String workingDirectory;

  SkillDeployCommand(
    this.input, {
    required this.assets,
    this.environment,
    this.approver,
    this.now,
    String? workingDirectory,
  }) : workingDirectory = workingDirectory ?? Directory.current.path;

  @override
  String? validate() {
    if (!assets.directoryExists('skills')) {
      return 'No skills found in the installed assets. Run: macss upgrade --apply';
    }
    return input.flags.validate();
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

    final resolved = <String, HostPaths>{};
    for (final host in hosts) {
      final paths = hostPaths(host, environment: environment);
      if (paths == null) {
        return SkillDeployOutput(
          message: 'Cannot resolve the home directory for host "$host". '
              'Set HOME or USERPROFILE.',
          exitCode: ExitCode.genericError,
        );
      }
      resolved[host] = paths;
    }

    // Deploying touches directories under the user's home that no repository
    // records, and it removes retired skills as well as adding new ones. The
    // dry run is the same traversal, so the plan names every removal too.
    final preview = <String>[];
    for (final entry in resolved.entries) {
      preview.add('${entry.key} → ${entry.value.skillsDirectory}');
      preview.addAll(deploySkills(
        assets: assets,
        targetDir: entry.value.skillsDirectory,
        dryRun: true,
      ));
    }

    final decision = await ChangeGate(
      flags: input.flags,
      approver: approver,
      now: now,
    ).decide(
      command: 'skill deploy',
      workingDirectory: workingDirectory,
      body: ['would deploy the MACSS skills:', '', ...preview].join('\n'),
    );

    if (!decision.proceed) {
      return SkillDeployOutput(
        message: decision.message!,
        hosts: hosts,
        exitCode: decision.blocked ? ExitCode.genericError : ExitCode.ok,
      );
    }

    final steps = <String>[];
    for (final entry in resolved.entries) {
      steps.add('${entry.key} → ${entry.value.skillsDirectory}');
      steps.addAll(
        deploySkills(assets: assets, targetDir: entry.value.skillsDirectory),
      );
    }

    return SkillDeployOutput(message: steps.join('\n'), hosts: hosts);
  }
}
