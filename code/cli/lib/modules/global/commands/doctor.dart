/// `macss doctor` — verifies local installation and assets integrity.
library;

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import '../../../assets.dart';
import '../../../src/version.dart';

// ─── Check types ─────────────────────────────────────────────────────────────

enum CheckStatus { ok, error }

class DoctorCheck {
  final String name;
  final CheckStatus status;
  final String detail;
  final String? remediation;

  const DoctorCheck({
    required this.name,
    required this.status,
    required this.detail,
    this.remediation,
  });
}

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
  Map<String, dynamic> toJson() => {
    'checks': checks
        .map(
          (c) => {
            'name': c.name,
            'status': c.status.name,
            'detail': c.detail,
            if (c.remediation != null) 'remediation': c.remediation,
          },
        )
        .toList(),
  };

  @override
  int get exitCode =>
      checks.any((c) => c.status == CheckStatus.error) ? 1 : ExitCode.ok;

  @override
  String? toText() {
    final buf = StringBuffer();
    for (final check in checks) {
      final icon = check.status == CheckStatus.ok ? '✓' : '✗';
      buf.writeln('  $icon  ${check.name}  ${check.detail}');
      if (check.remediation != null) {
        buf.writeln('       → ${check.remediation}');
      }
    }
    return buf.toString();
  }
}

// ─── Command ────────────────────────────────────────────────────────────────

class DoctorCommand implements Command<DoctorInput, DoctorOutput> {
  @override
  final DoctorInput input;

  final Assets assets;

  DoctorCommand(this.input, {required this.assets});

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
    // Labels come from the map, not from the path's basename: four skills all
    // end in `SKILL.md`, so a basename label would render four identical rows
    // and hide which one is actually missing.
    const requiredAssets = <String, String>{
      'template: 0001-record-architecture-decisions.md':
          'templates/project-base/docs/adr/0001-record-architecture-decisions.md',
      'template: architecture.md': 'templates/project-base/docs/architecture.md',
      'template: roadmap.md': 'templates/project-base/docs/roadmap.md',
      'artifact: requisition': 'artifacts/requisition.template.en.md',
      'artifact: specification': 'artifacts/specification.template.en.md',
      'artifact: issue': 'artifacts/issue.template.en.md',
      'skill: macss-specification': 'skills/macss-specification/SKILL.md',
      'skill: macss-analyze': 'skills/macss-analyze/SKILL.md',
      'skill: macss-plan': 'skills/macss-plan/SKILL.md',
      'skill: macss-execute': 'skills/macss-execute/SKILL.md',
    };

    for (final entry in requiredAssets.entries) {
      final exists = assets.fileExists(entry.value);
      checks.add(
        DoctorCheck(
          name: entry.key,
          status: exists ? CheckStatus.ok : CheckStatus.error,
          detail: exists ? 'found' : 'missing',
          remediation: exists ? null : 'Run: macss upgrade',
        ),
      );
    }

    return DoctorOutput(checks: checks);
  }
}
