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
import '../../../src/vocabulary.dart';
import '../../requisition/requisition_record.dart';
import '../../requisition/publisher.dart';
import '../../requisition/steps.dart';
import '../slug.dart';
import '../specification_gate.dart';
import '../workspace.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class SpecificationPublishInput extends Input {
  final String? slug;
  final String? repo;

  SpecificationPublishInput({this.slug, this.repo});

  factory SpecificationPublishInput.fromCliRequest(CliRequest req) =>
      SpecificationPublishInput(
        slug: optionalSlug(req.flagString('slug')),
        repo: req.flagString('repo'),
      );

  static final List<CliParam> params = [
    CliParam.string('slug',
        description: 'Requisition to publish; defaults to the active one'),
    CliParam.string('repo',
        description:
            'Target repository; by default gh infers it from this directory'),
  ];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {'slug': slug, 'repo': repo};
}

// ─── Output ─────────────────────────────────────────────────────────────────

class SpecificationPublishOutput extends Output {
  SpecificationPublishOutput({this.issue, this.url});

  final int? issue;
  final String? url;

  @override
  Map<String, dynamic> toJson() => {
    if (issue != null) 'issue': issue,
    if (url != null) 'url': url,
  };

  @override
  int get exitCode => ExitCode.ok;

  @override
  String? toText() => 'Issue $issue updated: $url';
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

  SpecificationPublishCommand(
    this.input, {
    required this.workingDirectory,
    required ProcessRunner runProcess,
    required Assets assets,
    SpecificationGate? gate,
  })  : publisher = IssuePublisher(runProcess: runProcess),
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
    return null;
  }

  /// Two steps: the issue, then the state it earns.
  ///
  /// The order is the guarantee. The contract is on the issue, so the
  /// requirement is specified — and a state written before `gh` returned would
  /// claim something the platform never received. That used to be a comment
  /// above two consecutive lines; it is now the order of the list, and the plan
  /// shows it.
  @override
  Future<List<Step>> steps() async {
    final dir = _dir!;
    final record = RequisitionRecord.read(dir)!;

    final result = gate.evaluate(
      File(p.join(dir, 'specification.md')).readAsStringSync(),
    );
    if (!result.passed) {
      throw CommandException(
        code: 'SPECIFICATION_NOT_READY',
        message: [
          'The contract is not ready, so there is nothing worth publishing yet:',
          ...result.violations.map((v) => '  - ${v.code}: ${v.message}'),
        ].join('\n'),
      );
    }

    final body = assembleBody(dir);
    if (body.exceedsLimit) {
      throw CommandException(
        code: 'BODY_TOO_LONG',
        message: 'The assembled body is ${body.length} characters; GitHub '
            'accepts $githubBodyLimit. Shorten ${body.parts.join(' + ')}, or '
            'split the requisition into smaller ones.',
      );
    }

    return [
      PublishIssue(
        publisher: publisher,
        record: record,
        body: body,
        dir: dir,
        repo: input.repo,
      ),
      RecordRequisitionState(
        record: record,
        dir: dir,
        state: RequisitionState.specified,
      ),
    ];
  }

  @override
  SpecificationPublishOutput describe(Execution execution) {
    final published = execution.outcomes.firstOrNull;
    return SpecificationPublishOutput(
      issue: published?.values['issue'] as int?,
      url: published?.values['url'] as String?,
    );
  }
}
