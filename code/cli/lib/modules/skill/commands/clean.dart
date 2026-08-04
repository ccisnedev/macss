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
import '../../../src/plan_apply.dart';
import '../host.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class SkillCleanInput extends Input {
  final String? host;
  final ChangeFlags flags;

  SkillCleanInput({this.host, this.flags = const ChangeFlags()});

  factory SkillCleanInput.fromCliRequest(CliRequest req) => SkillCleanInput(
        host: req.flagString('host'),
        flags: ChangeFlags.fromCliRequest(req),
      );

  static final List<CliParam> params = [
    CliParam.string(
      'host',
      allowed: supportedHosts,
      description:
          'Clean this assistant only; defaults to every one installed',
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
  final Approver? approver;
  final DateTime Function()? now;
  final String workingDirectory;

  SkillCleanCommand(
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
      return 'No skills found in the installed assets. Run: macss upgrade';
    }
    return input.flags.validate();
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
    final resolved = <String, HostPaths>{};
    for (final host in hosts) {
      final paths = hostPaths(host, environment: environment);
      if (paths == null) {
        return SkillCleanOutput(
          message: 'Cannot resolve the home directory for host "$host". '
              'Set HOME or USERPROFILE.',
          exitCode: ExitCode.genericError,
        );
      }
      resolved[host] = paths;
    }

    // The only command in the CLI whose whole purpose is to delete. Naming
    // every directory it would remove, before removing any, is the least this
    // convention is for.
    final doomed = <String>[];
    final preview = <String>[];
    for (final entry in resolved.entries) {
      preview.add('${entry.key} → ${entry.value.skillsDirectory}');
      for (final name in names) {
        final dir = Directory(p.join(entry.value.skillsDirectory, name));
        if (dir.existsSync()) {
          preview.add('  remove   $name');
          doomed.add(name);
        } else {
          preview.add('  absent   $name');
        }
      }
    }

    final decision = await ChangeGate(
      flags: input.flags,
      approver: approver,
      now: now,
    ).decide(
      command: 'skill clean',
      workingDirectory: workingDirectory,
      body: [
        doomed.isEmpty
            ? 'would remove nothing — no MACSS skill is deployed:'
            : 'would remove ${doomed.toSet().length} deployed MACSS skill(s):',
        '',
        ...preview,
      ].join('\n'),
    );

    if (!decision.proceed) {
      return SkillCleanOutput(
        message: decision.message!,
        exitCode: decision.blocked ? ExitCode.genericError : ExitCode.ok,
      );
    }

    final steps = <String>[];
    final removed = <String>[];
    for (final entry in resolved.entries) {
      steps.add('${entry.key} → ${entry.value.skillsDirectory}');
      for (final name in names) {
        final dir = Directory(p.join(entry.value.skillsDirectory, name));
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
