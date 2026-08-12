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
import '../../delivery/steps.dart';
import '../../requisition/steps.dart';
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

  VerificationPublishInput({this.slug, this.repo});

  factory VerificationPublishInput.fromCliRequest(CliRequest req) =>
      VerificationPublishInput(
        slug: optionalSlug(req.flagString('slug')),
        repo: req.flagString('repo'),
      );

  static final List<CliParam> params = [
    CliParam.string('slug',
        description: 'Requisition to publish; defaults to the active one'),
    CliParam.string('repo',
        description: 'owner/name; defaults to what gh infers here'),
  ];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {'slug': slug, 'repo': repo};
}

// ─── Output ─────────────────────────────────────────────────────────────────

class VerificationPublishOutput extends Output {
  VerificationPublishOutput({this.pr, this.url, this.recordedState});

  final int? pr;
  final String? url;
  final String? recordedState;

  @override
  Map<String, dynamic> toJson() => {
    if (pr != null) 'pr': pr,
    if (url != null) 'url': url,
    if (recordedState != null) 'state': recordedState,
  };

  @override
  int get exitCode => ExitCode.ok;

  @override
  String? toText() => [
    'Evidence added to pull request #$pr: $url',
    if (recordedState != null) '  recorded state: $recordedState',
  ].join('\n');
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
  final GitRunner runGit;

  VerificationPublishCommand(
    this.input, {
    required this.workingDirectory,
    required this.runProcess,
    required Assets assets,
    GitRunner? runGit,
    this.verificationGate = const VerificationGate(),
    SpecificationGate? specificationGate,
  })  : publisher = PullRequestPublisher(runProcess: runProcess),
        specificationGate = specificationGate ??
            SpecificationGate(vocabulary: Vocabularies.fromAssets(assets)),
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
    return null;
  }

  /// Three steps: push, publish, record.
  ///
  /// The push is a safety net rather than a requirement — verification produces
  /// no code, so nothing to push is the ordinary case. It is a step all the
  /// same, because the plan has to say that a push may happen before one does,
  /// and because a push that fails is worth reporting even where it is allowed
  /// to.
  @override
  Future<List<Step>> steps() async {
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
      throw CommandException(
        code: 'NO_FROZEN_CONTRACT',
        message: contract.failure!,
      );
    }

    final result = verificationGate.evaluate(
      File(p.join(dir, 'verification.md')).readAsStringSync(),
      criteria: contract.ids,
    );
    if (!result.passed) {
      throw CommandException(
        code: 'VERIFICATION_INCOMPLETE',
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
      throw CommandException(
        code: 'BODY_TOO_LONG',
        message: 'The assembled body is ${annotated.length} characters; GitHub '
            'accepts $githubBodyLimit. Shorten ${body.parts.join(' + ')}.',
      );
    }

    return [
      PushBranch(runGit: runGit, branch: null, required: false),
      PublishPullRequest(
        publisher: publisher,
        record: record,
        body: annotated,
        base: record.base ?? '',
        head: record.head ?? '',
        dir: dir,
        repo: input.repo,
      ),
      RecordRequisitionState(
        record: record,
        dir: dir,
        state: RequisitionState.verified,
      ),
    ];
  }

  @override
  VerificationPublishOutput describe(Execution execution) {
    final published = execution.outcomes
        .where((o) => o.values.containsKey('pr'))
        .firstOrNull;
    final recorded = execution.outcomes
        .where((o) => o.verb == 'record')
        .firstOrNull;
    return VerificationPublishOutput(
      pr: published?.values['pr'] as int?,
      url: published?.values['url'] as String?,
      recordedState: recorded?.values['state'] as String?,
    );
  }
}
