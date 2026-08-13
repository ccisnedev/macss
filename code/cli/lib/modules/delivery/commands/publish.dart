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
import '../../../src/vocabulary.dart';
import '../../requisition/publisher.dart';
import '../../requisition/requisition_record.dart';
import '../../specification/slug.dart';
import '../../specification/specification_gate.dart';
import '../../specification/workspace.dart';
import '../delivery_gate.dart';
import '../pull_request_publisher.dart';
import '../steps.dart';
import 'check.dart' show GitRunner;

// ─── Input ──────────────────────────────────────────────────────────────────

class DeliveryPublishInput extends Input {
  final String? slug;
  final String? repo;

  DeliveryPublishInput({this.slug, this.repo});

  factory DeliveryPublishInput.fromCliRequest(CliRequest req) =>
      DeliveryPublishInput(
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

class DeliveryPublishOutput extends Output {
  DeliveryPublishOutput({
    required this.updated,
    this.pr,
    this.url,
    this.base,
    this.head,
    this.recorded = false,
  });

  /// Whether an open pull request was updated rather than a new one opened.
  final bool updated;

  final int? pr;
  final String? url;
  final String? base;
  final String? head;

  /// Whether the number was written into the record — only ever on an open.
  final bool recorded;

  @override
  Map<String, dynamic> toJson() => {
    'updated': updated,
    if (pr != null) 'pr': pr,
    if (url != null) 'url': url,
    if (base != null) 'base': base,
    if (head != null) 'head': head,
    'recorded': recorded,
  };

  @override
  int get exitCode => ExitCode.ok;

  @override
  String? toText() => [
    'Pull request ${updated ? 'updated' : 'opened'}: $url',
    if (recorded && pr != null)
      '  recorded pr: $pr ($head → $base) in ${RequisitionRecord.fileName}',
  ].join('\n');
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
  final GitRunner runGit;

  DeliveryPublishCommand(
    this.input, {
    required this.workingDirectory,
    required ProcessRunner runProcess,
    required Assets assets,
    GitRunner? runGit,
    this.deliveryGate = const DeliveryGate(),
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
    if (RequisitionRecord.read(dir) == null) {
      return 'No ${RequisitionRecord.fileName} in ${p.basename(dir)}.';
    }
    if (!File(p.join(dir, 'delivery.md')).existsSync()) {
      return 'No delivery.md — run `macss delivery new --apply` first.';
    }
    return null;
  }

  bool _wasDelivered = false;
  String? _base;
  String? _head;

  /// Three steps: push, publish, record — and the order is the whole point.
  ///
  /// The push comes first because `gh pr create` resolves the head on the
  /// remote, and a branch the remote has never seen is not there to resolve.
  /// The record comes last because a pull request number written before `gh`
  /// returned would claim something the platform never received. Both used to
  /// be comments above consecutive statements; the plan shows them now.
  @override
  Future<List<Step>> steps() async {
    final dir = _dir!;
    final record = RequisitionRecord.read(dir)!;
    _wasDelivered = record.isDelivered;

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
      throw CommandException(
        code: 'DELIVERY_NOT_READY',
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
      throw CommandException(
        code: 'BRANCHES_UNKNOWN',
        message: 'Cannot tell which branches this would go between — git '
            'answered for neither HEAD nor origin/HEAD. Run '
            '`macss delivery check` to see which.',
      );
    }
    _base = base;
    _head = head;

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

    final publish = PublishPullRequest(
      publisher: publisher,
      record: record,
      body: annotated,
      base: base,
      head: head,
      dir: dir,
      repo: input.repo,
    );

    return [
      PushBranch(runGit: runGit, branch: head),
      publish,
      // A pull request that already has a number has nothing to record: the
      // record is where the number came from.
      if (!record.isDelivered)
        RecordDelivered(
          source: publish,
          record: record,
          dir: dir,
          base: base,
          head: head,
        ),
    ];
  }

  @override
  DeliveryPublishOutput describe(Execution execution) {
    final published = execution.outcomes
        .where((o) => o.values.containsKey('pr'))
        .firstOrNull;
    return DeliveryPublishOutput(
      updated: _wasDelivered,
      pr: published?.values['pr'] as int?,
      url: published?.values['url'] as String?,
      base: _base,
      head: _head,
      recorded: execution.outcomes.any((o) => o.verb == 'record'),
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
