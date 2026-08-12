/// `macss doctor` — verifies local installation and assets integrity.
library;

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import '../../../assets.dart';
import '../../../src/checks.dart';
import '../../../src/tools.dart';
import '../../../src/version.dart';

export '../../../src/checks.dart' show CheckStatus, DoctorCheck;

// ─── Input ──────────────────────────────────────────────────────────────────

class DoctorInput extends Input {
  DoctorInput();

  factory DoctorInput.fromCliRequest(CliRequest req) => DoctorInput();

  /// Empty contract: `doctor` takes no option, so any option is rejected.
  static const List<CliParam> params = [];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {};
}

// ─── Output ─────────────────────────────────────────────────────────────────

class DoctorOutput extends Output {
  final List<DoctorCheck> checks;

  DoctorOutput({required this.checks});

  @override
  Map<String, dynamic> toJson() =>
      {'checks': checks.map((c) => c.toJson()).toList()};

  @override
  int get exitCode => hasError(checks) ? 1 : ExitCode.ok;

  @override
  String? toText() => renderChecks(checks);
}

// ─── Command ────────────────────────────────────────────────────────────────

class DoctorCommand implements Query<DoctorInput, DoctorOutput> {
  @override
  final DoctorInput input;

  final Assets assets;

  /// Injected in tests so the PATH lookup is deterministic.
  final Map<String, String>? environment;

  DoctorCommand(this.input, {required this.assets, this.environment});

  @override
  String? validate() => null;

  @override
  Future<DoctorOutput> execute() async {
    final checks = <DoctorCheck>[];

    // Check 1: Version (always ok — binary is running)
    checks.add(
      const DoctorCheck(
        name: 'macss',
        status: CheckStatus.ok,
        detail: macssVersion,
      ),
    );

    // Check 2: Assets directory
    final assetsOk = assets.directoryExists('templates');
    checks.add(
      DoctorCheck(
        name: 'assets',
        status: assetsOk ? CheckStatus.ok : CheckStatus.error,
        detail: assetsOk ? 'found' : 'missing',
        remediation: assetsOk ? null : 'Reinstall MACSS CLI',
      ),
    );

    // Check 3+: every asset the commands need at runtime.
    //
    // Labels come from the map, not from the path's basename: the skills all
    // end in `SKILL.md`, so a basename label would render identical rows and
    // hide which one is actually missing.
    //
    // The list is written out rather than derived from the shipped directory,
    // and that is deliberate: deriving it from the directory this inspects
    // would make it vacuous, since a deleted skill would stop being listed
    // instead of being reported. A broken installation is what doctor is for.
    // A test keeps the list complete — see doctor_test.dart.
    const requiredAssets = <String, String>{
      'template: 0001-record-architecture-decisions.md':
          'templates/project-base/docs/adr/0001-record-architecture-decisions.md',
      'template: architecture.md': 'templates/project-base/docs/architecture.md',
      'template: roadmap.md': 'templates/project-base/docs/roadmap.md',
      'template: CHANGELOG.md': 'templates/project-base/CHANGELOG.md',
      'vocabulary: en': 'vocabulary/en.yaml',
      'vocabulary: es': 'vocabulary/es.yaml',
      'artifact: requisition': 'artifacts/requisition.template.en.md',
      'artifact: specification': 'artifacts/specification.template.en.md',
      'skill: macss-specification': 'skills/macss-specification/SKILL.md',
      'skill: macss-analyze': 'skills/macss-analyze/SKILL.md',
      'skill: macss-plan': 'skills/macss-plan/SKILL.md',
      'skill: macss-execute': 'skills/macss-execute/SKILL.md',
      'skill: macss-verification': 'skills/macss-verification/SKILL.md',
    };

    for (final entry in requiredAssets.entries) {
      final exists = assets.fileExists(entry.value);
      checks.add(
        DoctorCheck(
          name: entry.key,
          status: exists ? CheckStatus.ok : CheckStatus.error,
          detail: exists ? 'found' : 'missing',
          remediation: exists ? null : 'Run: macss upgrade --apply',
        ),
      );
    }

    // External toolchain. A missing tool never fails the command: `doctor`
    // answers whether the CLI itself is sound, and these narrow what you can do
    // rather than breaking what you have.
    for (final tool in externalTools) {
      final present = isOnPath(tool.executable, environment: environment);
      checks.add(
        DoctorCheck(
          name: tool.executable,
          status: present ? CheckStatus.ok : CheckStatus.warning,
          detail: present ? 'on PATH' : 'not found — ${tool.neededFor}',
          remediation: present ? null : 'Install: ${tool.install}',
        ),
      );
    }

    return DoctorOutput(checks: checks);
  }
}
