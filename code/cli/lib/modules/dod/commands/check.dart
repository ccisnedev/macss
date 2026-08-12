/// `macss dod check [--slug <slug>]` — the Definition of Done gate.
///
/// The mirror of `dor check`. It **composes** the stage gates rather than
/// replacing them — the delivery judges the implementer's claim, the record
/// judges the verifier's judgement — and adds what neither owns: that the work
/// has a pull request. From here the pull-request body freezes, as the issue
/// body freezes at the Definition of Ready.
///
/// It reads the contract from the platform **once** and hands the same criteria
/// to both gates. Composing means one question asked in one place: two gates
/// each fetching their own copy could disagree about what the contract says.
///
/// Review is not in it. ADR 0008 and the roadmap both decide this the same way:
/// review fires on the pull request, on the platform, and joins when that
/// integration exists. Until then the floor is these three.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../assets.dart';
import '../../../src/checks.dart';
import '../../../src/vocabulary.dart';
import '../../delivery/delivery_gate.dart';
import '../../requisition/publisher.dart';
import '../../requisition/requisition_record.dart';
import '../../specification/slug.dart';
import '../../specification/specification_gate.dart';
import '../../specification/workspace.dart';
import '../../verification/contract_source.dart';
import '../../verification/verification_gate.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class DodCheckInput extends Input {
  final String? slug;

  DodCheckInput({this.slug});

  factory DodCheckInput.fromCliRequest(CliRequest req) =>
      DodCheckInput(slug: optionalSlug(req.flagString('slug')));

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

class DodCheckOutput extends Output {
  final List<DoctorCheck> checks;
  final String name;

  DodCheckOutput({required this.checks, required this.name});

  bool get done => !hasError(checks);

  @override
  Map<String, dynamic> toJson() => {
        'done': done,
        'requisition': name,
        'checks': checks.map((c) => c.toJson()).toList(),
      };

  @override
  int get exitCode => done ? ExitCode.ok : ExitCode.validationFailed;

  @override
  String? toText() {
    final buffer = StringBuffer(renderChecks(checks));
    buffer.writeln();
    buffer.writeln(
      done
          ? 'Definition of Done met. From here the pull-request body is frozen: '
              'a change after this opens new work rather than editing the '
              'record of what was delivered.'
          : 'Not done. Fix what is marked above and re-run.',
    );
    return buffer.toString();
  }
}

// ─── Command ────────────────────────────────────────────────────────────────

class DodCheckCommand implements Command<DodCheckInput, DodCheckOutput> {
  @override
  final DodCheckInput input;

  final String workingDirectory;
  final ProcessRunner runProcess;
  final SpecificationGate specificationGate;
  final DeliveryGate deliveryGate;
  final VerificationGate verificationGate;

  DodCheckCommand(
    this.input, {
    required this.workingDirectory,
    required this.runProcess,
    required Assets assets,
    this.deliveryGate = const DeliveryGate(),
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
  Future<DodCheckOutput> execute() async {
    final dir = _dir!;
    final record = RequisitionRecord.read(dir);

    if (record == null) {
      return DodCheckOutput(
        name: p.basename(dir),
        checks: const [
          DoctorCheck(
            name: 'record',
            status: CheckStatus.error,
            detail: 'no readable ${RequisitionRecord.fileName}',
          ),
        ],
      );
    }

    final contract = record.isPublished
        ? await criteriaFromPlatform(record,
            runProcess: runProcess, gate: specificationGate)
        : const ContractCriteria.unavailable(
            'The requisition was never published, so there is no frozen '
            'contract to judge against.');

    final output = DodCheckOutput(
      name: p.basename(dir),
      checks: [
        _deliveryCheck(dir, record, contract),
        _verificationCheck(dir, contract),
        _pullRequestCheck(record),
      ],
    );

    // As at the Definition of Ready: the gate records what it establishes, a
    // gate that did not pass establishes nothing, and it never moves the state
    // backwards.
    if (output.done && record.state.isBefore(RequisitionState.done)) {
      record.at(RequisitionState.done).write(dir);
    }

    return output;
  }

  DoctorCheck _deliveryCheck(
    String dir,
    RequisitionRecord record,
    ContractCriteria contract,
  ) {
    final file = File(p.join(dir, 'delivery.md'));
    if (!file.existsSync()) {
      return const DoctorCheck(
        name: 'delivery',
        status: CheckStatus.error,
        detail: 'nothing says what was built',
        remediation: 'Run: macss delivery new --apply',
      );
    }
    if (!contract.ok) {
      return DoctorCheck(
        name: 'delivery',
        status: CheckStatus.error,
        detail: 'the contract could not be read',
        remediation: contract.failure,
      );
    }

    final result = deliveryGate.evaluate(
      file.readAsStringSync(),
      criteria: contract.ids,
      prTitle: record.prTitle,
    );
    return result.passed
        ? const DoctorCheck(
            name: 'delivery',
            status: CheckStatus.ok,
            detail: 'every criterion claimed',
          )
        : DoctorCheck(
            name: 'delivery',
            status: CheckStatus.error,
            detail: 'unmet: ${result.violations.map((v) => v.code).join(', ')}',
            remediation: 'Run: macss delivery check',
          );
  }

  DoctorCheck _verificationCheck(String dir, ContractCriteria contract) {
    final file = File(p.join(dir, 'verification.md'));
    if (!file.existsSync()) {
      return const DoctorCheck(
        name: 'verification',
        status: CheckStatus.error,
        detail: 'nothing says it was verified',
        remediation: 'Run: macss verification new --apply',
      );
    }
    if (!contract.ok) {
      return DoctorCheck(
        name: 'verification',
        status: CheckStatus.error,
        detail: 'the contract could not be read',
        remediation: contract.failure,
      );
    }

    final result =
        verificationGate.evaluate(file.readAsStringSync(), criteria: contract.ids);
    return result.passed
        ? const DoctorCheck(
            name: 'verification',
            status: CheckStatus.ok,
            detail: 'every criterion judged, and concluded',
          )
        : DoctorCheck(
            name: 'verification',
            status: CheckStatus.error,
            detail: 'unmet: ${result.violations.map((v) => v.code).join(', ')}',
            remediation: 'Run: macss verification check',
          );
  }

  /// What neither stage gate owns: the work has a vehicle.
  ///
  /// Answered from `state.pr` rather than from the platform. The number is
  /// written by the command that created the pull request, and asking GitHub
  /// whether its own answer is true would be a second answer to a question that
  /// already has one.
  DoctorCheck _pullRequestCheck(RequisitionRecord record) => DoctorCheck(
        name: 'pull request',
        status: record.isDelivered ? CheckStatus.ok : CheckStatus.error,
        detail: record.isDelivered
            ? 'opened as #${record.pr} (${record.head} → ${record.base})'
            : 'not opened',
        remediation:
            record.isDelivered ? null : 'Run: macss delivery publish --apply',
      );
}
