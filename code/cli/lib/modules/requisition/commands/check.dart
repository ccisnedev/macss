/// `macss requisition check [--slug <slug>]` — is every section of the form
/// answered?
///
/// Runs the requisition gate over the active requisition. It judges presence,
/// not quality: what catches a pretty phrase is the next stage, where QA has to
/// turn the stated value into an observable signal.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../specification/slug.dart';
import '../../specification/workspace.dart';
import '../requisition_gate.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class RequisitionCheckInput extends Input {
  final String? slug;

  RequisitionCheckInput({this.slug});

  factory RequisitionCheckInput.fromCliRequest(CliRequest req) =>
      RequisitionCheckInput(slug: optionalSlug(req.flagString('slug')));

  static final List<CliParam> params = [
    CliParam.string(
      'slug',
      description: 'Requisition to check; defaults to the active one',
    ),
  ];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {'slug': slug};
}

// ─── Output ─────────────────────────────────────────────────────────────────

class RequisitionCheckOutput extends Output {
  final String message;
  final List<RequisitionViolation> violations;

  RequisitionCheckOutput({required this.message, this.violations = const []});

  bool get passed => violations.isEmpty;

  @override
  Map<String, dynamic> toJson() => {
        'passed': passed,
        'message': message,
        'violations': violations
            .map((v) => {'code': v.code, 'message': v.message})
            .toList(),
      };

  @override
  int get exitCode => passed ? ExitCode.ok : ExitCode.validationFailed;

  @override
  String? toText() => message;
}

// ─── Command ────────────────────────────────────────────────────────────────

class RequisitionCheckCommand
    implements Command<RequisitionCheckInput, RequisitionCheckOutput> {
  @override
  final RequisitionCheckInput input;

  final String workingDirectory;
  final RequisitionGate gate;

  RequisitionCheckCommand(
    this.input, {
    required this.workingDirectory,
    this.gate = const RequisitionGate(),
  });

  String? get _dir => resolveRequisitionDir(workingDirectory, input.slug);

  @override
  String? validate() {
    // Ambiguity is answered with the candidates, never resolved by picking one.
    final ambiguous = ambiguousRequisitionFailure(workingDirectory, input.slug);
    if (ambiguous != null) return ambiguous;
    final dir = _dir;
    if (dir == null) {
      return 'No requisition found — run `macss requisition new <slug>` first, '
          'or point at one with --slug <slug>.';
    }
    if (!File(p.join(dir, 'requisition.md')).existsSync()) {
      return 'No requisition.md in ${p.basename(dir)} — the form is missing.';
    }
    return null;
  }

  @override
  Future<RequisitionCheckOutput> execute() async {
    final dir = _dir!;
    final name = p.basename(dir);
    final result = gate.evaluate(
      File(p.join(dir, 'requisition.md')).readAsStringSync(),
    );

    if (result.passed) {
      return RequisitionCheckOutput(
        message: 'requisition "$name" is complete — every section is answered.',
      );
    }

    return RequisitionCheckOutput(
      message: [
        'requisition "$name" is NOT complete — fix these and re-run:',
        ...result.violations.map((v) => '  - ${v.code}: ${v.message}'),
      ].join('\n'),
      violations: result.violations,
    );
  }
}
