/// `macss uninstall` — removes MACSS CLI from the system.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../targets/platform_ops.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class UninstallInput extends Input {
  final String installDir;

  UninstallInput({required this.installDir});

  factory UninstallInput.fromCliRequest(CliRequest req) => UninstallInput(
    installDir: p.dirname(p.dirname(Platform.resolvedExecutable)),
  );

  /// The install dir is derived, so this command takes nothing but the three
  /// flags the SDK gives every command.
  static const List<CliParam> params = [];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {'installDir': installDir};
}

// ─── Steps ──────────────────────────────────────────────────────────────────

/// Takes the CLI's `bin/` off the user's PATH.
class UnsetFromPath implements Step {
  UnsetFromPath({required this.platformOps, required this.binDir});

  final PlatformOps platformOps;
  final String binDir;

  String get _target => '$binDir from your PATH';

  @override
  Preview preview() => Preview(verb: 'unset', target: _target);

  @override
  Future<Outcome> perform(StepContext context) async {
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
    return Outcome(verb: 'unset', target: _target);
  }

  bool _pathEquals(String a, String b) =>
      p.normalize(a).toLowerCase() == p.normalize(b).toLowerCase();
}

/// Schedules the installation directory for deletion.
///
/// Scheduled rather than done: on Windows the running executable lives inside
/// it and cannot delete itself.
class DeleteInstallation implements Step {
  DeleteInstallation({required this.platformOps, required this.installDir});

  final PlatformOps platformOps;
  final String installDir;

  @override
  Preview preview() => Preview(
    verb: 'delete',
    target: installDir,
    detail:
        'requisitions, projects and anything under version control are not '
        'touched — this removes the tool, not your work',
  );

  @override
  Future<Outcome> perform(StepContext context) async {
    await platformOps.scheduleDeletion(installDir);
    return Outcome(verb: 'delete', target: installDir);
  }
}

// ─── Output ─────────────────────────────────────────────────────────────────

class UninstallOutput extends Output {
  UninstallOutput({required this.installDir});

  final String installDir;

  @override
  Map<String, dynamic> toJson() => {'installDir': installDir};

  @override
  int get exitCode => ExitCode.ok;

  @override
  String? toText() =>
      'MACSS CLI uninstalled. Restart your terminal to apply PATH changes.';
}

// ─── Command ────────────────────────────────────────────────────────────────

class UninstallCommand implements Command<UninstallInput, UninstallOutput> {
  @override
  final UninstallInput input;

  final PlatformOps platformOps;

  UninstallCommand(this.input, {PlatformOps? platformOps})
    : platformOps = platformOps ?? PlatformOps.current();

  @override
  String? validate() => null;

  /// PATH first, then the directory.
  ///
  /// The order is not cosmetic: unsetting PATH after scheduling the deletion
  /// would leave a window in which the entry points at a directory already on
  /// its way out.
  @override
  Future<List<Step>> steps() async => [
    UnsetFromPath(
      platformOps: platformOps,
      binDir: p.join(input.installDir, 'bin'),
    ),
    DeleteInstallation(
      platformOps: platformOps,
      installDir: input.installDir,
    ),
  ];

  @override
  UninstallOutput describe(Execution execution) =>
      UninstallOutput(installDir: input.installDir);
}
