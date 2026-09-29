/// Contributes MACSS's own doctor checks (version, shipped assets, external
/// toolchain) to the `doctor.checks` extension point [DoctorPlugin] declares.
///
/// `doctor` itself is owned entirely by `modular_cli_sdk`'s own
/// [DoctorPlugin]; [InstallationPlugin] separately contributes its own
/// `release` check. This plugin only adds the checks that are specific to
/// what MACSS itself ships and needs.
library;

import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import '../../assets.dart';
import '../../src/tools.dart';
import '../../src/version.dart';

class MacssDoctorChecksPlugin implements CliPlugin {
  MacssDoctorChecksPlugin({required Assets assets, this.environment})
    : _assets = assets;

  final Assets _assets;

  /// Injected in tests so the PATH lookup is deterministic.
  final Map<String, String>? environment;

  @override
  CliPluginManifest get manifest => const CliPluginManifest(
    id: 'macss.doctor_checks',
    displayName: 'MACSS doctor checks',
    version: '1.0.0',
    hostApiVersion: '^$cliPluginHostApiVersion',
    requires: ['modular_cli.doctor'],
  );

  @override
  void setup(CliPluginHost host) {
    host.contribute<CliDoctorCheck>(
      DoctorPlugin.extensionPoint,
      CliDoctorCheck(name: 'macss', run: _checkVersion),
    );
    host.contribute<CliDoctorCheck>(
      DoctorPlugin.extensionPoint,
      CliDoctorCheck(name: 'assets', run: _checkAssetsDirectory),
    );

    // Every asset the commands need at runtime.
    //
    // Labels come from the map, not from the path's basename: the skills all
    // end in `SKILL.md`, so a basename label would render identical rows and
    // hide which one is actually missing.
    //
    // The list is written out rather than derived from the shipped
    // directory, and that is deliberate: deriving it from the directory this
    // inspects would make it vacuous, since a deleted skill would stop being
    // listed instead of being reported. A broken installation is what
    // doctor is for. A test keeps the list complete: see doctor_test.dart.
    for (final entry in _requiredAssets.entries) {
      host.contribute<CliDoctorCheck>(
        DoctorPlugin.extensionPoint,
        CliDoctorCheck(
          name: entry.key,
          run: () async => _checkAsset(entry.value),
        ),
      );
    }

    // External toolchain. A missing tool never fails `doctor`: it answers
    // whether the CLI itself is sound, and these narrow what you can do
    // rather than breaking what you have.
    for (final tool in externalTools) {
      host.contribute<CliDoctorCheck>(
        DoctorPlugin.extensionPoint,
        CliDoctorCheck(
          name: tool.executable,
          run: () async => _checkTool(tool),
        ),
      );
    }
  }

  static const _requiredAssets = <String, String>{
    'template: 0001-record-architecture-decisions.md':
        'templates/project-base/docs/adr/0001-record-architecture-decisions.md',
    'template: architecture.md': 'templates/project-base/docs/architecture.md',
    'template: roadmap.md': 'templates/project-base/docs/roadmap.md',
    'template: CHANGELOG.md': 'templates/project-base/CHANGELOG.md',
    'vocabulary: en': 'vocabulary/en.yaml',
    'vocabulary: es': 'vocabulary/es.yaml',
    'artifact: requisition': 'artifacts/requisition.template.en.md',
    'artifact: specification': 'artifacts/specification.template.en.md',
    'skill: macss-specification':
        'skills/modules/lifecycle/macss-specification/SKILL.md',
    'skill: macss-analyze': 'skills/modules/lifecycle/macss-analyze/SKILL.md',
    'skill: macss-plan': 'skills/modules/lifecycle/macss-plan/SKILL.md',
    'skill: macss-execute': 'skills/modules/lifecycle/macss-execute/SKILL.md',
    'skill: macss-verification':
        'skills/modules/lifecycle/macss-verification/SKILL.md',
  };

  Future<CliCheckResult> _checkVersion() async =>
      const CliCheckResult(status: CliCheckStatus.ok, message: macssVersion);

  Future<CliCheckResult> _checkAssetsDirectory() async {
    final ok = _assets.directoryExists('templates');
    return CliCheckResult(
      status: ok ? CliCheckStatus.ok : CliCheckStatus.error,
      message: ok ? 'found' : 'missing. Reinstall MACSS CLI',
    );
  }

  Future<CliCheckResult> _checkAsset(String relativePath) async {
    final exists = _assets.fileExists(relativePath);
    return CliCheckResult(
      status: exists ? CliCheckStatus.ok : CliCheckStatus.error,
      message: exists ? 'found' : 'missing. Run: macss upgrade --apply',
    );
  }

  Future<CliCheckResult> _checkTool(ExternalTool tool) async {
    final present = isOnPath(tool.executable, environment: environment);
    return CliCheckResult(
      status: present ? CliCheckStatus.ok : CliCheckStatus.warning,
      message: present
          ? 'on PATH'
          : 'not found, needed for ${tool.neededFor}. Install: ${tool.install}',
    );
  }
}
