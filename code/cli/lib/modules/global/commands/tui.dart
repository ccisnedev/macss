/// `macss` — TUI banner with version, commands and alias.
library;

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import '../../../src/version.dart';
import '../../../src/version_check.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class TuiInput extends Input {
  TuiInput();

  factory TuiInput.fromCliRequest(CliRequest req) => TuiInput();

  /// Empty contract: the root banner takes no option.
  static const List<CliParam> params = [];

  @override
  List<CliParam> get schemaFields => params;

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
  final Future<VersionCheckResult> Function({required String currentVersion})?
      _versionChecker;

  TuiCommand(this.input, {
    Future<VersionCheckResult> Function({required String currentVersion})?
        versionChecker,
  }) : _versionChecker = versionChecker;

  @override
  String? validate() => null;

  @override
  Future<TuiOutput> execute() async {
    var banner = _buildBanner(macssVersion);

    try {
      final checker = _versionChecker ??
          ({required String currentVersion}) =>
              checkLatestVersion(currentVersion: currentVersion);
      final result = await checker(currentVersion: macssVersion);
      if (result.updateAvailable && result.latestVersion != null) {
        banner += "\n  Update available: $macssVersion → ${result.latestVersion}"
            " — run 'macss upgrade'";
      }
    } catch (_) {
      // Silent on failure
    }

    return TuiOutput(version: macssVersion, banner: banner);
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────────

const _r = '\x1B[0m';
const _b = '\x1B[1m';
const _d = '\x1B[2m';
const _grn = '\x1B[32m';
const _blu = '\x1B[34m';
const _cyn = '\x1B[36m';
const _wht = '\x1B[97m';

String _buildBanner(String version) {
  final logo =
      '\n$_wht   █▀   ▀█$_r'
      '\n$_grn      ●   $_r    $_b${_blu}macss$_r v$version'
      '\n$_wht   █▄   ▄█$_r    ${_d}Modular Architecture for Comprehensive Software Solutions$_r'
  ;

  final commands =
      '  ${_d}Commands:$_r\n'
      '    ${_cyn}create$_r $_d<path>$_r    scaffold a MACSS project\n'
      '    ${_cyn}doctor$_r            verify local installation\n'
      '    ${_cyn}upgrade$_r           update to latest version\n'
      '    ${_cyn}uninstall$_r         remove MACSS CLI\n'
      '    ${_cyn}version$_r           print version'
  ;

  final footer =
      '  ${_d}Quickstart:$_r  macss create my-project'
  ;

  return '$logo\n\n$commands\n\n$footer';
}
