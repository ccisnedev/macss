/// `macss delivery check [--slug <slug>]` — the delivery gate.
///
/// It changes nothing, so it declares neither `--plan` nor `--apply` and
/// rejects both (ADR 0007 applies to commands that write).
///
/// It reads the contract from **disk**, not from the platform. This runs on the
/// machine that specified and implemented, where `specification.md` is there by
/// construction. `macss verification new` reads the published body instead,
/// because the verifier may hold no copy at all. Same document, two readers
/// with different guarantees.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../assets.dart';
import '../../../src/checks.dart';
import '../../../src/vocabulary.dart';
import '../../requisition/requisition_record.dart';
import '../../specification/slug.dart';
import '../../specification/specification_gate.dart';
import '../../specification/workspace.dart';
import '../delivery_gate.dart';

/// Runs a process and returns its result — injected so the branch rule can be
/// exercised without a repository.
typedef GitRunner = ProcessResult Function(List<String> arguments);

// ─── Input ──────────────────────────────────────────────────────────────────

class DeliveryCheckInput extends Input {
  final String? slug;

  DeliveryCheckInput({this.slug});

  factory DeliveryCheckInput.fromCliRequest(CliRequest req) =>
      DeliveryCheckInput(slug: optionalSlug(req.flagString('slug')));

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

class DeliveryCheckOutput extends Output {
  final List<DoctorCheck> checks;
  final String name;

  DeliveryCheckOutput({required this.checks, required this.name});

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
          ? 'The delivery is well formed.'
          : 'Not ready. Fix what is marked above and re-run.',
    );
    return buffer.toString();
  }
}

// ─── Command ────────────────────────────────────────────────────────────────

class DeliveryCheckCommand
    implements Query<DeliveryCheckInput, DeliveryCheckOutput> {
  @override
  final DeliveryCheckInput input;

  final String workingDirectory;
  final SpecificationGate specificationGate;
  final DeliveryGate deliveryGate;
  final GitRunner runGit;

  DeliveryCheckCommand(
    this.input, {
    required this.workingDirectory,
    required Assets assets,
    this.deliveryGate = const DeliveryGate(),
    SpecificationGate? specificationGate,
    GitRunner? runGit,
  })  : specificationGate = specificationGate ??
            SpecificationGate(vocabulary: Vocabularies.fromAssets(assets)),
        runGit = runGit ??
            ((args) => Process.runSync('git', args,
                workingDirectory: workingDirectory));

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
  Future<DeliveryCheckOutput> execute() async {
    final dir = _dir!;

    return DeliveryCheckOutput(
      name: p.basename(dir),
      checks: [
        _documentCheck(dir),
        _branchCheck(),
      ],
    );
  }

  DoctorCheck _documentCheck(String dir) {
    final delivery = File(p.join(dir, 'delivery.md'));
    if (!delivery.existsSync()) {
      return DoctorCheck(
        name: 'delivery',
        status: CheckStatus.error,
        detail: 'the delivery was never opened',
        remediation: 'Run: macss delivery new --apply',
      );
    }

    final contract = File(p.join(dir, 'specification.md'));
    if (!contract.existsSync()) {
      return DoctorCheck(
        name: 'delivery',
        status: CheckStatus.error,
        detail: 'no contract to deliver against',
        remediation: 'Run: macss specification new --apply',
      );
    }

    final result = deliveryGate.evaluate(
      delivery.readAsStringSync(),
      criteria: specificationGate.acIds(contract.readAsStringSync()),
      prTitle: RequisitionRecord.read(dir)?.prTitle,
    );

    if (result.passed) {
      return DoctorCheck(
        name: 'delivery',
        status: CheckStatus.ok,
        detail: 'every criterion claimed, with somewhere to look',
      );
    }

    // The codes, not the prose. The messages are long by design — they say what
    // to do — and repeating them here would bury the one thing this answers.
    return DoctorCheck(
      name: 'delivery',
      status: CheckStatus.error,
      detail: 'unmet: ${result.violations.map((v) => v.code).join(', ')}',
      remediation: result.violations.first.message,
    );
  }

  /// The branch a pull request could be opened from.
  ///
  /// `gh pr create` cannot accept a head that is also the base, so this is the
  /// last gate before that failure would land with all the work already done.
  ///
  /// When `origin/HEAD` is not set the rule cannot answer, and it **warns**
  /// rather than refusing: a gate that blocks on an unconfigured ref would stop
  /// the work for a reason that has nothing to do with the delivery.
  DoctorCheck _branchCheck() {
    final head = _git(['rev-parse', '--abbrev-ref', 'HEAD']);
    if (head == null) {
      return const DoctorCheck(
        name: 'branch',
        status: CheckStatus.warning,
        detail: 'not a git repository, so there is no branch to check',
      );
    }

    final base = _git(['rev-parse', '--abbrev-ref', 'origin/HEAD']);
    if (base == null) {
      return DoctorCheck(
        name: 'branch',
        status: CheckStatus.warning,
        detail: 'on "$head"; origin/HEAD is not set, so the default branch is '
            'unknown',
        remediation: 'Run: git remote set-head origin --auto',
      );
    }

    // `origin/HEAD` resolves to `origin/main`; the branch is the last segment.
    final defaultBranch = base.split('/').last;
    if (head == defaultBranch) {
      return DoctorCheck(
        name: 'branch',
        status: CheckStatus.error,
        detail: 'on "$head", which is the default branch',
        remediation: 'A pull request cannot be opened from the branch it would '
            'merge into. Move the work onto a branch of its own.',
      );
    }

    return DoctorCheck(
      name: 'branch',
      status: CheckStatus.ok,
      detail: '"$head", onto "$defaultBranch"',
    );
  }

  String? _git(List<String> arguments) {
    try {
      final result = runGit(arguments);
      if (result.exitCode != 0) return null;
      final out = result.stdout.toString().trim();
      return out.isEmpty ? null : out;
    } on Object {
      // No git on the machine is the same answer as no repository: the rule
      // cannot be applied, and it says so instead of failing the delivery.
      return null;
    }
  }
}
