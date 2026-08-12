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

import '../../specification/slug.dart';
import '../../specification/workspace.dart';
import '../requisition_record.dart';
import '../publisher.dart';
import '../requisition_gate.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class RequisitionPublishInput extends Input {
  final String? slug;
  final String? repo;

  RequisitionPublishInput({this.slug, this.repo});

  factory RequisitionPublishInput.fromCliRequest(CliRequest req) =>
      RequisitionPublishInput(
        slug: optionalSlug(req.flagString('slug')),
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
  ];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {'slug': slug, 'repo': repo};
}

// ─── Steps ──────────────────────────────────────────────────────────────────

/// Creates or updates the issue on GitHub.
///
/// The issue's number and URL do not exist until it does, so the preview
/// **declares** them rather than staying silent: a plan that listed this step
/// without saying what it could not yet know would read as complete when it
/// was not. The step after this one reads the number from here rather than
/// asking GitHub a second time.
class PublishIssue implements Step {
  PublishIssue({
    required this.publisher,
    required this.record,
    required this.body,
    required this.dir,
    this.repo,
  });

  final IssuePublisher publisher;
  final RequisitionRecord record;

  /// Assembled when this step was built, and not again — it is what is going to
  /// GitHub, and what the plan counted the lines of.
  final AssembledBody body;

  final String dir;
  final String? repo;

  String get _verb => record.isPublished ? 'update' : 'create';

  String get _target =>
      'the issue for "${p.basename(dir)}"${repo == null ? '' : ' in $repo'}';

  @override
  Preview preview() => Preview(
    verb: _verb,
    target: _target,
    // The exact `gh` line is part of the claim: what reaches GitHub is the
    // thing being approved, and a reviewer who cannot see the command cannot
    // judge it.
    detail: [
      'title: ${record.title}',
      'labels: ${record.labels.isEmpty ? '(none)' : record.labels.join(', ')}',
      '${body.lines} lines from ${body.parts.join(' + ')}',
      if (repo == null) 'repo inferred by gh from this directory',
      'gh ${publisher.plannedArgs(record, repo: repo).join(' ')} '
          '--body-file <body>',
    ].join('; '),
    pending: const ['issue', 'url'],
  );

  @override
  Future<Outcome> perform(StepContext context) async {
    final result = await publisher.publish(record, body, repo: repo);
    if (!result.ok) throw StateError(result.error!);

    return Outcome(
      verb: _verb,
      target: _target,
      values: {'issue': result.number, 'url': result.url},
    );
  }
}

/// Writes the issue number into the requisition's record.
///
/// It reads the number from [source] rather than from GitHub: asking twice
/// could answer differently, and this step is not the one that knows how to ask.
class RecordIssueNumber implements Step {
  RecordIssueNumber({
    required this.source,
    required this.record,
    required this.dir,
  });

  final Step source;
  final RequisitionRecord record;
  final String dir;

  @override
  Preview preview() => Preview(
    verb: 'record',
    target: '${p.basename(dir)}/${RequisitionRecord.fileName}',
    pending: const ['issue'],
  );

  @override
  Future<Outcome> perform(StepContext context) async {
    final number = context.outcomeOf(source).values['issue'] as int?;
    if (number != null) record.published(number).write(dir);

    return Outcome(
      verb: 'record',
      target: '${p.basename(dir)}/${RequisitionRecord.fileName}',
      values: {'issue': number},
    );
  }
}

// ─── Output ─────────────────────────────────────────────────────────────────

class RequisitionPublishOutput extends Output {
  RequisitionPublishOutput({
    required this.updated,
    this.issue,
    this.url,
    this.recorded = false,
  });

  /// Whether an existing issue was updated rather than a new one created.
  final bool updated;

  final int? issue;
  final String? url;

  /// Whether the number was written into the record — only ever on a create.
  final bool recorded;

  @override
  Map<String, dynamic> toJson() => {
    'updated': updated,
    if (issue != null) 'issue': issue,
    if (url != null) 'url': url,
    'recorded': recorded,
  };

  @override
  int get exitCode => ExitCode.ok;

  @override
  String? toText() => [
    'Issue ${updated ? 'updated' : 'created'}: $url',
    if (recorded && issue != null)
      '  recorded issue: $issue in ${RequisitionRecord.fileName}',
  ].join('\n');
}

// ─── Command ────────────────────────────────────────────────────────────────

class RequisitionPublishCommand
    implements Command<RequisitionPublishInput, RequisitionPublishOutput> {
  @override
  final RequisitionPublishInput input;

  final String workingDirectory;
  final IssuePublisher publisher;

  /// Whether the Product Owner's form is answered at all. A different gate on
  /// a different question from `--plan` / `--apply`, which is why the two were
  /// never one — and the other now belongs to the SDK.
  final RequisitionGate gate;

  RequisitionPublishCommand(
    this.input, {
    required this.workingDirectory,
    required ProcessRunner runProcess,
    this.gate = const RequisitionGate(),
  }) : publisher = IssuePublisher(runProcess: runProcess);

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
    return null;
  }

  /// Whether the record already carried an issue when the steps were built.
  bool _wasPublished = false;

  /// One step to publish, and a second to record the number — but only when
  /// there is a number to record.
  ///
  /// The two checks that come first are not steps: they decide whether there is
  /// anything worth publishing at all, and a plan built from a requisition that
  /// cannot be published would describe work that will never happen.
  @override
  Future<List<Step>> steps() async {
    final dir = _dir!;
    final record = RequisitionRecord.read(dir)!;
    _wasPublished = record.isPublished;

    // Publishing an unanswered form has no purpose. The methodology check comes
    // first; the platform limit is a separate concern, checked after it.
    final form = File(p.join(dir, 'requisition.md'));
    if (form.existsSync()) {
      final result = gate.evaluate(form.readAsStringSync());
      if (!result.passed) {
        throw CommandException(
          code: 'REQUISITION_INCOMPLETE',
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
      throw CommandException(
        code: 'BODY_TOO_LONG',
        message:
            'The assembled body is ${body.length} characters; GitHub '
            'accepts $githubBodyLimit. Shorten ${body.parts.join(' + ')}, or '
            'split the requisition into smaller ones.',
      );
    }

    final publish = PublishIssue(
      publisher: publisher,
      record: record,
      body: body,
      dir: dir,
      repo: input.repo,
    );

    return [
      publish,
      // An issue that already has a number has nothing to record: the record is
      // where the number came from.
      if (!record.isPublished)
        RecordIssueNumber(source: publish, record: record, dir: dir),
    ];
  }

  @override
  RequisitionPublishOutput describe(Execution execution) {
    final published = execution.outcomes.firstOrNull;
    return RequisitionPublishOutput(
      updated: _wasPublished,
      issue: published?.values['issue'] as int?,
      url: published?.values['url'] as String?,
      recorded: execution.outcomes.any((o) => o.verb == 'record'),
    );
  }
}
