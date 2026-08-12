/// `macss specification publish --plan|--apply` — adds the contract to the
/// issue.
///
/// The issue already exists: `requisition publish` created it carrying the
/// request. This updates it so the body reads request first, contract second —
/// how a need became agreed work, top to bottom.
///
/// It requires both: an issue to update, and a contract worth publishing.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../assets.dart';
import '../../../src/plan_apply.dart';
import '../../../src/vocabulary.dart';
import '../../requisition/requisition_record.dart';
import '../../requisition/publisher.dart';
import '../slug.dart';
import '../specification_gate.dart';
import '../workspace.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class SpecificationPublishInput extends Input {
  final String? slug;
  final ChangeFlags flags;
  final String? repo;

  SpecificationPublishInput({
    this.slug,
    this.flags = const ChangeFlags(),
    this.repo,
  });

  factory SpecificationPublishInput.fromCliRequest(CliRequest req) =>
      SpecificationPublishInput(
        slug: optionalSlug(req.flagString('slug')),
        flags: ChangeFlags.fromCliRequest(req),
        repo: req.flagString('repo'),
      );

  static final List<CliParam> params = [
    CliParam.string('slug',
        description: 'Requisition to publish; defaults to the active one'),
    CliParam.string('repo',
        description:
            'Target repository; by default gh infers it from this directory'),
    ...ChangeFlags.params,
  ];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {
        'slug': slug,
        'repo': repo,
        'plan': flags.plan,
        'apply': flags.apply,
        'autoapprove': flags.autoapprove,
      };
}

// ─── Output ─────────────────────────────────────────────────────────────────

class SpecificationPublishOutput extends Output {
  final String message;
  final bool ok;
  final String? planPath;

  SpecificationPublishOutput({
    required this.message,
    this.ok = true,
    this.planPath,
  });

  @override
  Map<String, dynamic> toJson() =>
      {'ok': ok, 'message': message, if (planPath != null) 'planPath': planPath};

  @override
  int get exitCode => ok ? ExitCode.ok : ExitCode.genericError;

  @override
  String? toText() => message;
}

// ─── Command ────────────────────────────────────────────────────────────────

class SpecificationPublishCommand
    implements
        Command<SpecificationPublishInput, SpecificationPublishOutput> {
  @override
  final SpecificationPublishInput input;

  final String workingDirectory;
  final IssuePublisher publisher;

  /// Whether the contract is worth publishing.
  final SpecificationGate gate;

  /// Whether this run plans or applies.
  final ChangeGate changeGate;

  SpecificationPublishCommand(
    this.input, {
    required this.workingDirectory,
    required ProcessRunner runProcess,
    required Assets assets,
    SpecificationGate? gate,
    Approver? approver,
    DateTime Function()? now,
  })  : publisher = IssuePublisher(runProcess: runProcess),
        changeGate = ChangeGate(
          flags: input.flags,
          approver: approver,
          now: now,
        ),
        gate = gate ??
            SpecificationGate(vocabulary: Vocabularies.fromAssets(assets));

  String? get _dir => resolveRequisitionDir(workingDirectory, input.slug);

  @override
  String? validate() {
    // Ambiguity is answered with the candidates, never resolved by picking one.
    final ambiguous = ambiguousRequisitionFailure(workingDirectory, input.slug);
    if (ambiguous != null) return ambiguous;
    final dir = _dir;
    if (dir == null) {
      return 'No requisition found — run '
          '`macss requisition new <slug> --apply` first.';
    }
    if (!File(p.join(dir, 'specification.md')).existsSync()) {
      return 'No specification.md — run `macss specification new --apply` '
          'first.';
    }
    final meta = RequisitionRecord.read(dir);
    if (meta == null || !meta.isPublished) {
      return 'The requisition has not been published yet — run '
          '`macss requisition publish --apply` first, so there is an issue to '
          'add the contract to.';
    }
    return input.flags.validate();
  }

  @override
  Future<SpecificationPublishOutput> execute() async {
    final dir = _dir!;
    final meta = RequisitionRecord.read(dir)!;

    final result = gate.evaluate(
      File(p.join(dir, 'specification.md')).readAsStringSync(),
    );
    if (!result.passed) {
      return SpecificationPublishOutput(
        ok: false,
        message: [
          'The contract is not ready, so there is nothing worth publishing yet:',
          ...result.violations.map((v) => '  - ${v.code}: ${v.message}'),
        ].join('\n'),
      );
    }

    final body = assembleBody(dir);
    if (body.exceedsLimit) {
      return SpecificationPublishOutput(
        ok: false,
        message: 'The assembled body is ${body.length} characters; GitHub '
            'accepts $githubBodyLimit. Shorten ${body.parts.join(' + ')}, or '
            'split the requisition into smaller ones.',
      );
    }

    final decision = await changeGate.decide(
      command: 'specification publish',
      workingDirectory: workingDirectory,
      body: [
        'would update issue ${meta.issue}',
        '',
        '  body:   ${body.lines} lines from ${body.parts.join(' + ')}',
        '',
        'Would run:',
        '  gh ${publisher.plannedArgs(meta, repo: input.repo).join(' ')} '
            '--body-file <body>',
      ].join('\n'),
    );

    if (!decision.proceed) {
      return SpecificationPublishOutput(
        message: decision.message!,
        ok: !decision.blocked,
        planPath: decision.planPath,
      );
    }

    final published = await publisher.publish(meta, body, repo: input.repo);
    if (!published.ok) {
      return SpecificationPublishOutput(ok: false, message: published.error!);
    }

    // The contract is on the issue, so the requirement is specified. Recorded
    // only after `gh` returned: a state written before the call would claim
    // something the platform never received.
    meta.at(RequisitionState.specified).write(dir);

    return SpecificationPublishOutput(
        message: 'Issue ${meta.issue} updated: ${published.url}');
  }
}
