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

  factory UninstallInput.fromCliRequest(CliRequest req) {
    final installDir = p.dirname(p.dirname(Platform.resolvedExecutable));
    return UninstallInput(installDir: installDir);
  }

  /// Empty contract: `uninstall` takes no option (install dir is derived).
  static const List<CliParam> params = [];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {'installDir': installDir};
}

// ─── Output ─────────────────────────────────────────────────────────────────

class UninstallOutput extends Output {
  final String message;

  UninstallOutput({required this.message});

  @override
  Map<String, dynamic> toJson() => {'message': message};

  @override
  int get exitCode => ExitCode.ok;

  @override
  String? toText() => message;
}

// ─── Command ────────────────────────────────────────────────────────────────

class UninstallCommand implements Command<UninstallInput, UninstallOutput> {
  @override
  final UninstallInput input;

  final PlatformOps platformOps;

  UninstallCommand(
    this.input, {
    PlatformOps? platformOps,
  }) : platformOps = platformOps ?? PlatformOps.current();

  @override
  String? validate() => null;

  @override
  Future<UninstallOutput> execute() async {
    // 1. Remove bin dir from user PATH
    _removeFromPath(p.join(input.installDir, 'bin'));

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
