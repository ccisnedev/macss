/// `macss verification check [--slug <slug>]` — the verification gate.
///
/// It changes nothing, so it declares neither `--plan` nor `--apply`.
///
/// It reads the contract from the platform for the reason `verification new`
/// does: the verifier may hold no local copy, and the frozen issue body is what
/// is authoritative. ADR 0008 already records that the Definition of Done
/// "cannot be composed entirely from files on disk"; this is the first of it.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../assets.dart';
import '../../../src/checks.dart';
import '../../../src/vocabulary.dart';
import '../../requisition/publisher.dart';
import '../../requisition/requisition_record.dart';
import '../../specification/slug.dart';
import '../../specification/specification_gate.dart';
import '../../specification/workspace.dart';
import '../contract_source.dart';
import '../verification_gate.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class VerificationCheckInput extends Input {
  final String? slug;

  VerificationCheckInput({this.slug});

  factory VerificationCheckInput.fromCliRequest(CliRequest req) =>
      VerificationCheckInput(slug: optionalSlug(req.flagString('slug')));

  static final List<CliParam> params = [
    CliParam.string('slug',
        description: 'Requisition to check; defaults to the active one'),
  ];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {'slug': slug};
}

// ─── Output ─────────────────────────────────────────────────────────────────

class VerificationCheckOutput extends Output {
  final List<DoctorCheck> checks;
  final String name;

  VerificationCheckOutput({required this.checks, required this.name});

  bool get ready => !hasError(checks);

  @override
  Map<String, dynamic> toJson() => {
        'ready': ready,
        'requisition': name,
        'checks': checks.map((c) => c.toJson()).toList(),
      };

  @override
  int get exitCode => ready ? ExitCode.ok : ExitCode.validationFailed;

  @override
  String? toText() {
    final buffer = StringBuffer(renderChecks(checks));
    buffer.writeln();
    buffer.writeln(
      ready
          ? 'The record is complete: every criterion judged, and concluded by '
              'the person who answers for it.'
          : 'Not complete. Fix what is marked above and re-run.',
    );
    return buffer.toString();
  }
}

// ─── Command ────────────────────────────────────────────────────────────────

class VerificationCheckCommand
    implements Command<VerificationCheckInput, VerificationCheckOutput> {
  @override
  final VerificationCheckInput input;

  final String workingDirectory;
  final ProcessRunner runProcess;
  final SpecificationGate specificationGate;
  final VerificationGate verificationGate;

  VerificationCheckCommand(
    this.input, {
    required this.workingDirectory,
    required this.runProcess,
    required Assets assets,
    this.verificationGate = const VerificationGate(),
    SpecificationGate? specificationGate,
  }) : specificationGate = specificationGate ??
            SpecificationGate(vocabulary: Vocabularies.fromAssets(assets));

  String? get _dir => resolveRequisitionDir(workingDirectory, input.slug);

  @override
  String? validate() {
    final ambiguous = ambiguousRequisitionFailure(workingDirectory, input.slug);
    if (ambiguous != null) return ambiguous;
    if (_dir == null) {
      return 'No requisition found — run `macss requisition new <slug> --apply` '
          'first, or point at one with --slug <slug>.';
    }
    return null;
  }

  @override
  Future<VerificationCheckOutput> execute() async {
    final dir = _dir!;
    return VerificationCheckOutput(
      name: p.basename(dir),
      checks: [await _recordCheck(dir)],
    );
  }

  Future<DoctorCheck> _recordCheck(String dir) async {
    final file = File(p.join(dir, 'verification.md'));
    if (!file.existsSync()) {
      return const DoctorCheck(
        name: 'verification',
        status: CheckStatus.error,
        detail: 'the record was never opened',
        remediation: 'Run: macss verification new --apply',
      );
    }

    final record = RequisitionRecord.read(dir);
    if (record == null || !record.isPublished) {
      return const DoctorCheck(
        name: 'verification',
        status: CheckStatus.error,
        detail: 'no published contract to judge against',
      );
    }

    final contract = await criteriaFromPlatform(
      record,
      runProcess: runProcess,
      gate: specificationGate,
    );
    if (!contract.ok) {
      return DoctorCheck(
        name: 'verification',
        status: CheckStatus.error,
        detail: 'the contract could not be read',
        remediation: contract.failure,
      );
    }

    final result = verificationGate.evaluate(
      file.readAsStringSync(),
      criteria: contract.ids,
    );
    if (result.passed) {
      return DoctorCheck(
        name: 'verification',
        status: CheckStatus.ok,
        detail: '${contract.ids.length} criteria, all judged, and concluded',
      );
    }

    return DoctorCheck(
      name: 'verification',
      status: CheckStatus.error,
      detail: 'unmet: ${result.violations.map((v) => v.code).join(', ')}',
      remediation: result.violations.first.message,
    );
  }
}
