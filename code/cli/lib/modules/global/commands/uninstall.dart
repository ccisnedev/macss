/// `macss uninstall` — removes MACSS CLI from the system.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../src/plan_apply.dart';
import '../../../targets/platform_ops.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class UninstallInput extends Input {
  final String installDir;
  final ChangeFlags flags;

  UninstallInput({required this.installDir, this.flags = const ChangeFlags()});

  factory UninstallInput.fromCliRequest(CliRequest req) {
    final installDir = p.dirname(p.dirname(Platform.resolvedExecutable));
    return UninstallInput(
      installDir: installDir,
      flags: ChangeFlags.fromCliRequest(req),
    );
  }

  /// The install dir is derived, so the convention is the whole contract.
  static final List<CliParam> params = [...ChangeFlags.params];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {
        'installDir': installDir,
        'plan': flags.plan,
        'apply': flags.apply,
        'autoapprove': flags.autoapprove,
      };
}

// ─── Output ─────────────────────────────────────────────────────────────────

class UninstallOutput extends Output {
  final String message;
  final String? planPath;
  final bool blocked;

  UninstallOutput({required this.message, this.planPath, this.blocked = false});

  @override
  Map<String, dynamic> toJson() => {'message': message, 'planPath': planPath};

  @override
  int get exitCode => blocked ? ExitCode.genericError : ExitCode.ok;

  @override
  String? toText() => message;
}

// ─── Command ────────────────────────────────────────────────────────────────

class UninstallCommand implements Command<UninstallInput, UninstallOutput> {
  @override
  final UninstallInput input;

  final PlatformOps platformOps;
  final Approver? approver;
  final DateTime Function()? now;

  /// Where the plan goes. The install directory is about to be deleted, so it
  /// is the one place a plan for this command must not live.
  final String workingDirectory;

  UninstallCommand(
    this.input, {
    PlatformOps? platformOps,
    this.approver,
    this.now,
    String? workingDirectory,
  })  : platformOps = platformOps ?? PlatformOps.current(),
        workingDirectory = workingDirectory ?? Directory.current.path;

  @override
  String? validate() => input.flags.validate();

  @override
  Future<UninstallOutput> execute() async {
    final binDir = p.join(input.installDir, 'bin');

    final decision = await ChangeGate(
      flags: input.flags,
      approver: approver,
      now: now,
    ).decide(
      command: 'uninstall',
      workingDirectory: workingDirectory,
      body: [
        'would remove MACSS from this machine:',
        '',
        '  delete   ${input.installDir}',
        '  unset    $binDir from your PATH',
        '',
        'Requisitions, projects and anything under version control are not '
            'touched — this removes the tool, not your work.',
      ].join('\n'),
    );

    if (!decision.proceed) {
      return UninstallOutput(
        message: decision.message!,
        planPath: decision.planPath,
        blocked: decision.blocked,
      );
    }

    // 1. Remove bin dir from user PATH
    _removeFromPath(binDir);

    // 2. Schedule deletion of the install directory
    await platformOps.scheduleDeletion(input.installDir);

    return UninstallOutput(
      message:
          'MACSS CLI uninstalled. Restart your terminal to apply PATH changes.',
    );
  }

  void _removeFromPath(String binDir) {
    final userPath = platformOps.getEnvVariable('PATH') ?? '';
    final sep = Platform.isWindows ? ';' : ':';
    final parts = userPath
        .split(sep)
        .where((part) => part.isNotEmpty)
        .where((part) => !_pathEquals(part, binDir))
        .toList();
    final newPath = parts.join(sep);
    if (newPath != userPath) {
      platformOps.setEnvVariable('PATH', newPath);
    }
  }

  bool _pathEquals(String a, String b) =>
      p.normalize(a).toLowerCase() == p.normalize(b).toLowerCase();
}
