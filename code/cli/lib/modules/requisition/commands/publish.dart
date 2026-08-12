/// `macss requisition publish --plan|--apply [--repo <owner/repo>]` —
/// materializes the requisition as an issue.
///
/// Creates the issue the first time and updates it afterwards, so the same
/// command serves both moments: the request is published as soon as the Product
/// Owner delivers it, and the body grows when the specification is written.
///
/// Follows the `--plan` / `--apply` convention of ADR 0007. This is the command
/// the specification skill has been instructing as `--plan` since 0.5.0, an
/// invocation that until now failed with `unknown option --plan`.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../src/plan_apply.dart';
import '../../specification/slug.dart';
import '../../specification/workspace.dart';
import '../requisition_record.dart';
import '../publisher.dart';
import '../requisition_gate.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class RequisitionPublishInput extends Input {
  final String? slug;
  final ChangeFlags flags;
  final String? repo;

  RequisitionPublishInput({
    this.slug,
    this.flags = const ChangeFlags(),
    this.repo,
  });

  factory RequisitionPublishInput.fromCliRequest(CliRequest req) =>
      RequisitionPublishInput(
        slug: optionalSlug(req.flagString('slug')),
        flags: ChangeFlags.fromCliRequest(req),
        repo: req.flagString('repo'),
      );

  static final List<CliParam> params = [
    CliParam.string(
      'slug',
      description: 'Requisition to publish; defaults to the active one',
    ),
    CliParam.string(
      'repo',
      description:
          'Target repository; by default gh infers it from this directory',
    ),
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

class RequisitionPublishOutput extends Output {
  final String message;
  final bool ok;
  final int? issue;
  final String? planPath;

  RequisitionPublishOutput({
    required this.message,
    this.ok = true,
    this.issue,
    this.planPath,
  });

  @override
  Map<String, dynamic> toJson() => {
        'ok': ok,
        'message': message,
        if (issue != null) 'issue': issue,
        if (planPath != null) 'planPath': planPath,
      };

  @override
  int get exitCode => ok ? ExitCode.ok : ExitCode.genericError;

  @override
  String? toText() => message;
}

// ─── Command ────────────────────────────────────────────────────────────────

class RequisitionPublishCommand
    implements Command<RequisitionPublishInput, RequisitionPublishOutput> {
  @override
  final RequisitionPublishInput input;

  final String workingDirectory;
  final IssuePublisher publisher;

  /// Whether the Product Owner's form is answered at all.
  final RequisitionGate gate;

  /// Whether this run plans or applies. A different gate on a different
  /// question, which is why the two are not one.
  final ChangeGate changeGate;

  RequisitionPublishCommand(
    this.input, {
    required this.workingDirectory,
    required ProcessRunner runProcess,
    this.gate = const RequisitionGate(),
    Approver? approver,
    DateTime Function()? now,
  })  : publisher = IssuePublisher(runProcess: runProcess),
        changeGate = ChangeGate(
          flags: input.flags,
          approver: approver,
          now: now,
        );

  String? get _dir => resolveRequisitionDir(workingDirectory, input.slug);

  @override
  String? validate() {
    // Ambiguity is answered with the candidates, never resolved by picking one.
    final ambiguous = ambiguousRequisitionFailure(workingDirectory, input.slug);
    if (ambiguous != null) return ambiguous;
    final dir = _dir;
    if (dir == null) {
      return 'No requisition found — run `macss requisition new <slug> --apply` '
          'first, '
          'or point at one with --slug <slug>.';
    }
    if (RequisitionRecord.read(dir) == null) {
      return 'No ${RequisitionRecord.fileName} in ${p.basename(dir)}.';
    }
    return input.flags.validate();
  }

  @override
  Future<RequisitionPublishOutput> execute() async {
    final dir = _dir!;
    final meta = RequisitionRecord.read(dir)!;

    // Publishing an unanswered form has no purpose. The methodology check comes
    // first; the platform limit is a separate concern, checked below.
    final form = File(p.join(dir, 'requisition.md'));
    if (form.existsSync()) {
      final result = gate.evaluate(form.readAsStringSync());
      if (!result.passed) {
        return RequisitionPublishOutput(
          ok: false,
          message: [
            'The requisition is not complete, so there is nothing worth '
                'publishing yet:',
            ...result.violations.map((v) => '  - ${v.code}: ${v.message}'),
          ].join('\n'),
        );
      }
    }

    final body = assembleBody(dir);
    if (body.exceedsLimit) {
      return RequisitionPublishOutput(
        ok: false,
        message: 'The assembled body is ${body.length} characters; GitHub '
            'accepts $githubBodyLimit. Shorten ${body.parts.join(' + ')}, or '
            'split the requisition into smaller ones.',
      );
    }

    final verb = meta.isPublished ? 'update' : 'create';

    // One rendering, handed either to the plan file or to the approver. The
    // exact `gh` line is part of it: what reaches GitHub is the thing being
    // approved, and a reviewer who cannot see the command cannot judge it.
    final planBody = [
      'would $verb the issue for "${p.basename(dir)}"',
      '',
      '  title:  ${meta.title}',
      '  labels: ${meta.labels.isEmpty ? '(none)' : meta.labels.join(', ')}',
      '  body:   ${body.lines} lines from ${body.parts.join(' + ')}',
      if (input.repo == null) '  repo:   inferred by gh from this directory',
      '',
      'Would run:',
      '  gh ${publisher.plannedArgs(meta, repo: input.repo).join(' ')} '
          '--body-file <body>',
    ].join('\n');

    final decision = await changeGate.decide(
      command: 'requisition publish',
      workingDirectory: workingDirectory,
      body: planBody,
    );

    if (!decision.proceed) {
      return RequisitionPublishOutput(
        message: decision.message!,
        ok: !decision.blocked,
        planPath: decision.planPath,
      );
    }

    final result =
        await publisher.publish(meta, body, repo: input.repo);
    if (!result.ok) {
      return RequisitionPublishOutput(ok: false, message: result.error!);
    }

    if (result.number != null && !meta.isPublished) {
      meta.published(result.number!).write(dir);
    }

    return RequisitionPublishOutput(
      issue: result.number,
      message: [
        'Issue ${meta.isPublished ? 'updated' : 'created'}: ${result.url}',
        if (!meta.isPublished && result.number != null)
          '  recorded issue: ${result.number} in ${RequisitionRecord.fileName}',
      ].join('\n'),
    );
  }
}
