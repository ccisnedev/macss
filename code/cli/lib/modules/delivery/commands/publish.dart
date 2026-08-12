/// `macss delivery publish --plan|--apply` — the delivery becomes a pull
/// request.
///
/// The **first command in this CLI that writes outside the machine by a route
/// that is not `gh`**: it pushes the branch, because `gh pr create` needs a head
/// that exists on the remote. `--plan` therefore has to name the push and not
/// perform it, or the convention would be describing half of what happens.
///
/// The order is not incidental. Push, then open; a pull request asked for
/// against a branch the remote has never seen fails after all the work is done.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../assets.dart';
import '../../../src/plan_apply.dart';
import '../../../src/vocabulary.dart';
import '../../requisition/publisher.dart';
import '../../requisition/requisition_record.dart';
import '../../specification/slug.dart';
import '../../specification/specification_gate.dart';
import '../../specification/workspace.dart';
import '../delivery_gate.dart';
import '../pull_request_publisher.dart';
import 'check.dart' show GitRunner;

// ─── Input ──────────────────────────────────────────────────────────────────

class DeliveryPublishInput extends Input {
  final String? slug;
  final String? repo;
  final ChangeFlags flags;

  DeliveryPublishInput({this.slug, this.repo, required this.flags});

  factory DeliveryPublishInput.fromCliRequest(CliRequest req) =>
      DeliveryPublishInput(
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

class DeliveryPublishOutput extends Output {
  final String message;
  final bool ok;
  final String? planPath;
  final int? pr;

  DeliveryPublishOutput({
    required this.message,
    this.ok = true,
    this.planPath,
    this.pr,
  });

  @override
  Map<String, dynamic> toJson() =>
      {'message': message, 'ok': ok, 'planPath': planPath, 'pr': pr};

  @override
  int get exitCode => ok ? ExitCode.ok : ExitCode.genericError;

  @override
  String? toText() => message;
}

// ─── Command ────────────────────────────────────────────────────────────────

class DeliveryPublishCommand
    implements Command<DeliveryPublishInput, DeliveryPublishOutput> {
  @override
  final DeliveryPublishInput input;

  final String workingDirectory;
  final PullRequestPublisher publisher;
  final SpecificationGate specificationGate;
  final DeliveryGate deliveryGate;
  final ChangeGate changeGate;
  final GitRunner runGit;

  DeliveryPublishCommand(
    this.input, {
    required this.workingDirectory,
    required ProcessRunner runProcess,
    required Assets assets,
    GitRunner? runGit,
    Approver? approver,
    DateTime Function()? now,
    this.deliveryGate = const DeliveryGate(),
    SpecificationGate? specificationGate,
  })  : publisher = PullRequestPublisher(runProcess: runProcess),
        specificationGate = specificationGate ??
            SpecificationGate(vocabulary: Vocabularies.fromAssets(assets)),
        changeGate = ChangeGate(flags: input.flags, approver: approver, now: now),
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
    if (RequisitionRecord.read(dir) == null) {
      return 'No ${RequisitionRecord.fileName} in ${p.basename(dir)}.';
    }
    if (!File(p.join(dir, 'delivery.md')).existsSync()) {
      return 'No delivery.md — run `macss delivery new --apply` first.';
    }
    return input.flags.validate();
  }

  @override
  Future<DeliveryPublishOutput> execute() async {
    final dir = _dir!;
    final record = RequisitionRecord.read(dir)!;

    // The gate first: nothing leaves the machine on a red gate, and a push is
    // the one step of this command that cannot be taken back.
    final contract = File(p.join(dir, 'specification.md'));
    final result = deliveryGate.evaluate(
      File(p.join(dir, 'delivery.md')).readAsStringSync(),
      criteria: contract.existsSync()
          ? specificationGate.acIds(contract.readAsStringSync())
          : const [],
      prTitle: record.prTitle,
    );
    if (!result.passed) {
      return DeliveryPublishOutput(
        ok: false,
        message: [
          'The delivery is not ready, so there is nothing worth publishing yet:',
          ...result.violations.map((v) => '  - ${v.code}: ${v.message}'),
        ].join('\n'),
      );
    }

    final head = _git(['rev-parse', '--abbrev-ref', 'HEAD']);
    final base = _git(['rev-parse', '--abbrev-ref', 'origin/HEAD'])
        ?.split('/')
        .last;
    if (head == null || base == null) {
      return DeliveryPublishOutput(
        ok: false,
        message: 'Cannot tell which branches this would go between — git '
            'answered for neither HEAD nor origin/HEAD. Run '
            '`macss delivery check` to see which.',
      );
    }

    final body = assembleBody(dir, documents: pullRequestDocuments);
    final annotated = AssembledBody(
      '${issueReference(record.issue!)}\n\n${body.content}',
      body.parts,
    );
    if (annotated.exceedsLimit) {
      return DeliveryPublishOutput(
        ok: false,
        message: 'The assembled body is ${annotated.length} characters; GitHub '
            'accepts $githubBodyLimit. Shorten ${body.parts.join(' + ')}.',
      );
    }

    final verb = record.isDelivered ? 'update' : 'open';
    final decision = await changeGate.decide(
      command: 'delivery publish',
      workingDirectory: workingDirectory,
      body: [
        'would $verb the pull request for "${p.basename(dir)}"',
        '',
        '  title:  ${record.prTitle}',
        '  labels: '
            '${record.labels.isEmpty ? '(none)' : record.labels.join(', ')}',
        '  body:   ${annotated.lines} lines from ${body.parts.join(' + ')}',
        '  issue:  #${record.issue} (referenced, not closed)',
        '',
        'Would run:',
        '  git push --set-upstream origin $head',
        '  gh ${publisher.plannedArgs(record, base: base, head: head, repo: input.repo).join(' ')} '
            '--body-file <body>',
      ].join('\n'),
    );

    if (!decision.proceed) {
      return DeliveryPublishOutput(
        message: decision.message!,
        ok: !decision.blocked,
        planPath: decision.planPath,
      );
    }

    // Push first: `gh pr create` resolves the head on the remote, and a branch
    // it has never seen is not there to resolve.
    final push = runGit(['push', '--set-upstream', 'origin', head]);
    if (push.exitCode != 0) {
      return DeliveryPublishOutput(
        ok: false,
        message: 'git push failed:\n${push.stderr}'.trimRight(),
      );
    }

    final published =
        await publisher.publish(record, annotated,
            base: base, head: head, repo: input.repo);
    if (!published.ok) {
      return DeliveryPublishOutput(ok: false, message: published.error!);
    }

    final number = published.number;
    if (number != null && !record.isDelivered) {
      record.delivered(pr: number, base: base, head: head).write(dir);
    }

    return DeliveryPublishOutput(
      pr: number ?? record.pr,
      message: [
        'Pull request ${record.isDelivered ? 'updated' : 'opened'}: '
            '${published.url}',
        if (!record.isDelivered && number != null)
          '  recorded pr: $number ($head → $base) in '
              '${RequisitionRecord.fileName}',
      ].join('\n'),
    );
  }

  String? _git(List<String> arguments) {
    try {
      final result = runGit(arguments);
      if (result.exitCode != 0) return null;
      final out = result.stdout.toString().trim();
      return out.isEmpty ? null : out;
    } on Object {
      return null;
    }
  }
}
