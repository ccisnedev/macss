/// The shape of a verification result, shared by every command that inspects
/// something and reports a list of findings.
///
/// `macss doctor` inspects the CLI installation; `macss project check` inspects
/// a project against the canon. They report the same way so the two are read the
/// same way.
library;

/// The outcome of a single check.
///
/// [warning] exists because "something is missing" and "something is off" call
/// for different responses: a missing canonical file can be created, while an
/// extra or deviating one needs human judgement — a `code/legacy/` directory may
/// be deliberate debt, and a tool has no context to decide that.
enum CheckStatus { ok, warning, error }

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

  Map<String, dynamic> toJson() => {
    'name': name,
    'status': status.name,
    'detail': detail,
    if (remediation != null) 'remediation': remediation,
  };

  /// `✓` / `!` / `✗` — one glyph per status, so a report scans vertically.
  String get glyph => switch (status) {
    CheckStatus.ok => '✓',
    CheckStatus.warning => '!',
    CheckStatus.error => '✗',
  };
}

/// Renders [checks] as the indented, glyph-prefixed list both commands print.
String renderChecks(List<DoctorCheck> checks) {
  final buf = StringBuffer();
  for (final check in checks) {
    buf.writeln('  ${check.glyph}  ${check.name}  ${check.detail}');
    if (check.remediation != null) {
      buf.writeln('       → ${check.remediation}');
    }
  }
  return buf.toString();
}

/// Exit code for a set of checks: non-zero only when something is an [error].
///
/// A [warning] never fails the command — it is information that needs a human,
/// not a broken state.
bool hasError(List<DoctorCheck> checks) =>
    checks.any((c) => c.status == CheckStatus.error);
