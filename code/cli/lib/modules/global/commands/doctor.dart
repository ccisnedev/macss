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

    // Check 3-5: Required templates
    const templatePaths = [
      'templates/project-base/docs/adr/0001-record-architecture-decisions.md',
      'templates/project-base/docs/architecture.md',
      'templates/project-base/docs/roadmap.md',
      'artifacts/requisition.template.en.md',
      'artifacts/specification.template.en.md',
      'artifacts/issue.template.en.md',
      'skills/macss-specification/SKILL.md',
      'skills/macss-analyze/SKILL.md',
      'skills/macss-plan/SKILL.md',
      'skills/macss-execute/SKILL.md',
    ];

    for (final template in templatePaths) {
      final exists = assets.fileExists(template);
      final name = template.split('/').last;
      checks.add(
        DoctorCheck(
          name: 'template: $name',
          status: exists ? CheckStatus.ok : CheckStatus.error,
          detail: exists ? 'found' : 'missing',
          remediation: exists ? null : 'Run: macss upgrade',
        ),
      );
    }

    return DoctorOutput(checks: checks);
  }
}
