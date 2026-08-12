/// `macss verification publish --plan|--apply` — the evidence joins the pull
/// request.
///
/// It appends the record to the same pull request the delivery opened, the way
/// `specification publish` appends the contract to the issue the requisition
/// opened. The body then reads as one thing: what was built, and that it holds.
///
/// It pushes too, and there the push is a **safety net rather than a
/// requirement**: verification produces no code, so "everything up to date" is
/// the ordinary answer and is treated as success. What it covers is the walk
/// that turned up a fix.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../assets.dart';
import '../../../src/vocabulary.dart';
import '../../delivery/commands/check.dart' show GitRunner;
import '../../delivery/pull_request_publisher.dart';
import '../../requisition/publisher.dart';
import '../../requisition/requisition_record.dart';
import '../../specification/slug.dart';
import '../../specification/specification_gate.dart';
import '../../specification/workspace.dart';
import '../contract_source.dart';
import '../verification_gate.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class VerificationPublishInput extends Input {
  final String? slug;
  final String? repo;
  final ChangeFlags flags;

  VerificationPublishInput({this.slug, this.repo, required this.flags});

  factory VerificationPublishInput.fromCliRequest(CliRequest req) =>
      VerificationPublishInput(
        slug: optionalSlug(req.flagString('slug')),
        repo: req.flagString('repo'),
        flags: ChangeFlags.fromCliRequest(req),
      );

  static final List<CliParam> params = [
    CliParam.string('slug',
        description: 'Requisition to publish; defaults to the active one'),
    CliParam.string('repo',
        description: 'owner/name; defaults to what gh infers here'),
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

class VerificationPublishOutput extends Output {
  final String message;
  final bool ok;
  final String? planPath;

  VerificationPublishOutput({
    required this.message,
    this.ok = true,
    this.planPath,
  });

  @override
  Map<String, dynamic> toJson() =>
      {'message': message, 'ok': ok, 'planPath': planPath};

  @override
  int get exitCode => ok ? ExitCode.ok : ExitCode.genericError;

  @override
  String? toText() => message;
}

// ─── Command ────────────────────────────────────────────────────────────────

class VerificationPublishCommand
    implements Command<VerificationPublishInput, VerificationPublishOutput> {
  @override
  final VerificationPublishInput input;

  final String workingDirectory;
  final ProcessRunner runProcess;
  final PullRequestPublisher publisher;
  final SpecificationGate specificationGate;
  final VerificationGate verificationGate;
  final ChangeGate changeGate;
  final GitRunner runGit;

  VerificationPublishCommand(
    this.input, {
    required this.workingDirectory,
    required this.runProcess,
    required Assets assets,
    GitRunner? runGit,
    Approver? approver,
    DateTime Function()? now,
    this.verificationGate = const VerificationGate(),
    SpecificationGate? specificationGate,
  })  : publisher = PullRequestPublisher(runProcess: runProcess),
        specificationGate = specificationGate ??
            SpecificationGate(vocabulary: Vocabularies.fromAssets(assets)),
        changeGate =
            ChangeGate(flags: input.flags, approver: approver, now: now),
        runGit = runGit ??
            ((args) => Process.runSync('git', args,
                workingDirectory: workingDirectory));

  String? get _dir => resolveRequisitionDir(workingDirectory, input.slug);

  @override
  String? validate() {
    final ambiguous = ambiguousRequisitionFailure(workingDirectory, input.slug);
    if (ambiguous != null) return ambiguous;
    final dir = _dir;
    if (dir == null) {
      return 'No requisition found — run `macss requisition new <slug> --apply` '
          'first, or point at one with --slug <slug>.';
    }
    final record = RequisitionRecord.read(dir);
    if (record == null) {
      return 'No ${RequisitionRecord.fileName} in ${p.basename(dir)}.';
    }
    if (!record.isDelivered) {
      return 'There is no pull request to add the evidence to — run '
          '`macss delivery publish --apply` first.';
    }
    if (!File(p.join(dir, 'verification.md')).existsSync()) {
      return 'No verification.md — run `macss verification new --apply` first.';
    }
    return input.flags.validate();
  }

  @override
  Future<VerificationPublishOutput> execute() async {
    final dir = _dir!;
    final record = RequisitionRecord.read(dir)!;

    // The gate first, as everywhere: nothing reaches the pull request from a
    // record that is not finished, and a published half-walk reads like a
    // verification that happened.
    final contract = await criteriaFromPlatform(
      record,
      runProcess: runProcess,
      gate: specificationGate,
    );
    if (!contract.ok) {
      return VerificationPublishOutput(ok: false, message: contract.failure!);
    }

    final result = verificationGate.evaluate(
      File(p.join(dir, 'verification.md')).readAsStringSync(),
      criteria: contract.ids,
    );
    if (!result.passed) {
      return VerificationPublishOutput(
        ok: false,
        message: [
          'The record is not complete, so there is nothing worth publishing '
              'yet:',
          ...result.violations.map((v) => '  - ${v.code}: ${v.message}'),
        ].join('\n'),
      );
    }

    final body = assembleBody(dir, documents: pullRequestDocuments);
    final annotated = AssembledBody(
      '${issueReference(record.issue!)}\n\n${body.content}',
      body.parts,
    );
    if (annotated.exceedsLimit) {
      return VerificationPublishOutput(
        ok: false,
        message: 'The assembled body is ${annotated.length} characters; GitHub '
            'accepts $githubBodyLimit. Shorten ${body.parts.join(' + ')}.',
      );
    }

    final decision = await changeGate.decide(
      command: 'verification publish',
      workingDirectory: workingDirectory,
      body: [
        'would add the evidence to pull request #${record.pr}',
        '',
        '  body:     ${annotated.lines} lines from ${body.parts.join(' + ')}',
        '  criteria: ${contract.ids.length}, all judged',
        '  state:    ${record.state.name} → ${RequisitionState.verified.name}',
        '',
        'Would run:',
        '  git push',
        '  gh ${publisher.plannedArgs(record, base: record.base ?? '', head: record.head ?? '', repo: input.repo).join(' ')} '
            '--body-file <body>',
      ].join('\n'),
    );

    if (!decision.proceed) {
      return VerificationPublishOutput(
        message: decision.message!,
        ok: !decision.blocked,
        planPath: decision.planPath,
      );
    }

    // A safety net, not a requirement: verification produces no code, so
    // nothing to push is the ordinary case and is not a failure. What this
    // covers is the walk that turned up a fix.
    runGit(['push']);

    final published = await publisher.publish(
      record,
      annotated,
      base: record.base ?? '',
      head: record.head ?? '',
      repo: input.repo,
    );
    if (!published.ok) {
      return VerificationPublishOutput(ok: false, message: published.error!);
    }

    record.at(RequisitionState.verified).write(dir);

    return VerificationPublishOutput(
      message: [
        'Evidence added to pull request #${record.pr}: ${published.url}',
        '  recorded state: ${RequisitionState.verified.name}',
      ].join('\n'),
    );
  }
}
