/// Steps shared by more than one command in the `requisition` module — and by
/// the three other modules that publish to the same issue.
library;

import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../specification/workspace.dart';
import 'publisher.dart';
import 'requisition_record.dart';

/// Points `.macss/active_requisition.yaml` at one requisition.
///
/// Used by `activate`, which does only this, and by `new`, which does it last.
/// One step rather than one per command, so the pointer keeps its keys and its
/// format however it came to be written.
class RecordActiveRequisition implements Step {
  RecordActiveRequisition({
    required this.workingDirectory,
    required this.slug,
    required this.relDir,
    required this.isoDate,
  });

  final String workingDirectory;
  final String slug;
  final String relDir;
  final String isoDate;

  @override
  Preview preview() => Preview(
    verb: 'activate',
    target: relDir,
    detail: 'commands that take no --slug act on the active requisition',
  );

  @override
  Future<Outcome> perform(StepContext context) async {
    writeActiveRequisition(
      workingDirectory,
      slug: slug,
      relDir: relDir,
      isoDate: isoDate,
    );
    return Outcome(verb: 'activate', target: relDir, values: {'slug': slug});
  }
}

/// Creates or updates the requisition's issue on GitHub.
///
/// The number and URL do not exist until the issue does, so the preview
/// **declares** them rather than staying silent: a plan that listed this step
/// without saying what it could not yet know would read as complete when it
/// was not.
///
/// Shared by every command that puts a document on the issue — the requisition
/// itself, the contract, the delivery — because they differ only in what they
/// assembled, not in how it gets there.
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

  String get _target => record.isPublished
      ? 'issue ${record.issue}'
      : 'the issue for "${p.basename(dir)}"';

  @override
  Preview preview() => Preview(
    verb: _verb,
    target: '$_target${repo == null ? '' : ' in $repo'}',
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
      target: '$_target${repo == null ? '' : ' in $repo'}',
      values: {'issue': result.number ?? record.issue, 'url': result.url},
    );
  }
}

/// Moves the requisition to a state on the ladder.
///
/// Always a step *after* whatever justified the move, never before: a state
/// written ahead of the call that earns it claims something the platform never
/// received. Ordering is what makes that true, and the plan shows the order.
class RecordRequisitionState implements Step {
  RecordRequisitionState({
    required this.record,
    required this.dir,
    required this.state,
  });

  final RequisitionRecord record;
  final String dir;
  final RequisitionState state;

  String get _target => '${p.basename(dir)}/${RequisitionRecord.fileName}';

  @override
  Preview preview() =>
      Preview(verb: 'record', target: _target, detail: 'state: ${state.name}');

  @override
  Future<Outcome> perform(StepContext context) async {
    record.at(state).write(dir);
    return Outcome(
      verb: 'record',
      target: _target,
      values: {'state': state.name},
    );
  }
}
