/// `macss` — TUI banner with version, commands and alias.
library;

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import '../../../src/version.dart';
import '../../../src/version_check.dart';

// ─── Types ───────────────────────────────────────────────────────────────────

typedef VersionChecker =
    Future<VersionCheckResult> Function({required String currentVersion});

// ─── Input ──────────────────────────────────────────────────────────────────

class TuiInput extends Input {
  TuiInput();

  factory TuiInput.fromCliRequest(CliRequest req) => TuiInput();

  @override
  Map<String, dynamic> toJson() => {};
}

// ─── Output ─────────────────────────────────────────────────────────────────

class TuiOutput extends Output {
  final String version;
  final String banner;

  TuiOutput({required this.version, required this.banner});

  @override
  Map<String, dynamic> toJson() => {'version': version, 'banner': banner};

  @override
  int get exitCode => ExitCode.ok;

  @override
  String? toText() => banner;
}

// ─── Command ────────────────────────────────────────────────────────────────

class TuiCommand implements Command<TuiInput, TuiOutput> {
  @override
  final TuiInput input;

  final VersionChecker _versionChecker;

  TuiCommand(
    this.input, {
    VersionChecker? versionChecker,
  }) : _versionChecker = versionChecker ??
            (({required String currentVersion}) =>
                checkLatestVersion(currentVersion: currentVersion));

  @override
  String? validate() => null;

  @override
  Future<TuiOutput> execute() async {
    final updateResult = await _versionChecker(currentVersion: macssVersion);
    final banner = _buildBanner(updateResult);
    return TuiOutput(version: macssVersion, banner: banner);
  }

  String _buildBanner(VersionCheckResult update) {
    const grn = '\x1B[32m';
    const wht = '\x1B[97m';
    const dim = '\x1B[2m';
    const rst = '\x1B[0m';
    const cyn = '\x1B[36m';

    final updateLine = update.updateAvailable
        ? '\n  ${grn}New version available: ${update.latestVersion}  '
            'Run: macss upgrade$rst'
        : '';

// $grn  ██  ██▄▄▄██   ▀▀▀  ▀▀▀  ▀▀▀$rst
    return '''
$wht   █▀   ▀█ $rst
$grn      •   $rst
$wht   █▄   ▄█$rst
$wht  macss$rst  ${dim}v$macssVersion$rst  ${dim}Modular Architecture for Comprehensive Software Solutions$rst  ${dim}alias: ma$rst$updateLine

  ${dim}Commands:$rst
    ${cyn}create$rst $dim<path>$rst    scaffold a MACSS project
    ${cyn}doctor$rst            verify local installation
    ${cyn}upgrade$rst           update to latest version
    ${cyn}uninstall$rst         remove MACSS CLI
    ${cyn}version$rst           print version

  ${dim}Quickstart:$rst  macss create mi-proyecto
''';
  }
}
