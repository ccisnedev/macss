/// `macss skill deploy [--host <assistant>] --plan|--apply` — installs the
/// lifecycle skills the CLI ships into the assistant's own skills directory
/// under the user's home.
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
  SkillDeployInput({this.host});

  final String? host;

  factory SkillDeployInput.fromCliRequest(CliRequest req) =>
      SkillDeployInput(host: req.flagString('host'));

  /// Declared contract: an optional `--host`. Omitting it deploys to every
  /// installed assistant, which is the common case.
  ///
  /// `--plan`, `--apply` and `--autoapprove` are **not** here. The SDK declares
  /// them on every command, and listing them again would be a second place for
  /// the convention to be got wrong.
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

/// What the deployment did, per host.
///
/// It carries no `message`, no `planPath` and no `blocked`: those described the
/// gate, and the gate belongs to the SDK. What is left is what this command
/// produced.
class SkillDeployOutput extends Output {
  SkillDeployOutput(this.byHost);

  /// Host → the skills it touched, each with the verb that touched it.
  final Map<String, List<({String skill, String verb})>> byHost;

  List<String> get hosts => byHost.keys.toList();

  @override
  Map<String, dynamic> toJson() => {
    'hosts': hosts,
    'skills': {
      for (final entry in byHost.entries)
        entry.key: {for (final s in entry.value) s.skill: s.verb},
    },
  };

  @override
  int get exitCode => ExitCode.ok;

  @override
  String? toText() => [
    for (final entry in byHost.entries) ...[
      entry.key,
      ...entry.value.map((s) => '  ${s.verb.padRight(8)} ${s.skill}'),
    ],
  ].join('\n');
}

// ─── Command ────────────────────────────────────────────────────────────────

class SkillDeployCommand
    implements Command<SkillDeployInput, SkillDeployOutput> {
  SkillDeployCommand(this.input, {required this.assets, this.environment});

  @override
  final SkillDeployInput input;

  final Assets assets;
  final Map<String, String>? environment;

  @override
  String? validate() {
    if (!assets.directoryExists('skills')) {
      return 'No skills found in the installed assets. Run: macss upgrade --apply';
    }
    return null;
  }

  @override
  Future<List<Step>> steps() async {
    final hosts = input.host != null
        ? [input.host!]
        : detectHosts(environment: environment);

    // Not a validation failure — the invocation was well formed and there is
    // simply nothing here to deploy to. Thrown rather than returned so the
    // exit code stays what it has always been.
    if (hosts.isEmpty) {
      throw CommandException(
        code: 'NO_ASSISTANT_FOUND',
        message:
            'No supported assistant found in your home directory.\n'
            'Supported: ${supportedHosts.join(', ')}.\n'
            'Pass --host <assistant> to deploy anyway.',
        exitCode: ExitCode.notFound,
      );
    }

    return [
      for (final host in hosts)
        ...deploySkillSteps(
          assets: assets,
          targetDir: _pathsFor(host).skillsDirectory,
        ).map((step) => _tagged(step, host)),
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

  /// Wraps a step so its outcome carries the host it belongs to.
  ///
  /// The step's target is a full path, because the same skill name is deployed
  /// to more than one assistant in a single run and two identical lines in a
  /// plan tell a reader nothing. The short name and the host travel as values
  /// instead, which is what [describe] reports from.
  Step _tagged(Step step, String host) => _HostScoped(step, host);

  @override
  SkillDeployOutput describe(Execution execution) {
    final byHost = <String, List<({String skill, String verb})>>{};
    for (final outcome in execution.outcomes) {
      final host = outcome.values['host'] as String? ?? '';
      final skill = outcome.values['skill'] as String? ?? outcome.target;
      byHost.putIfAbsent(host, () => []).add((skill: skill, verb: outcome.verb));
    }
    return SkillDeployOutput(byHost);
  }
}

/// A step that reports which assistant it acted for.
///
/// A decorator rather than a parameter on every step type: which host a
/// deployment belongs to is a fact about *this command's* grouping, not about
/// writing a file, and pushing it into the deployer would make the deployer
/// know about hosts it has no other reason to know about.
class _HostScoped implements Step {
  const _HostScoped(this._inner, this._host);

  final Step _inner;
  final String _host;

  @override
  Preview preview() => _inner.preview();

  @override
  Future<Outcome> perform(StepContext context) async {
    final inner = _inner;
    final outcome = await inner.perform(context);
    return Outcome(
      verb: outcome.verb,
      target: outcome.target,
      detail: outcome.detail,
      values: {
        ...outcome.values,
        'host': _host,
        'skill': inner is DeploySkill ? inner.name : _basename(outcome.target),
      },
    );
  }

  static String _basename(String path) =>
      path.split(RegExp(r'[/\\]')).where((s) => s.isNotEmpty).last;
}
