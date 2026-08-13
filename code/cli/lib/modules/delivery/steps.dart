/// Steps for putting a document on a pull request.
///
/// Shared by `delivery publish`, which opens the pull request, and
/// `verification publish`, which adds the evidence to the one already open.
/// They differ in what they assembled, not in how it gets there.
library;

import 'dart:io';

import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../requisition/publisher.dart';
import '../requisition/requisition_record.dart';
import 'pull_request_publisher.dart';

/// Pushes the current branch to `origin`.
///
/// **First, always.** `gh pr create` resolves the head on the remote, and a
/// branch the remote has never seen is not there to resolve. Ordering used to
/// be a comment above two consecutive statements; it is the order of the list
/// now, and the plan shows it before anything leaves the machine.
class PushBranch implements Step {
  PushBranch({
    required this.runGit,
    required this.branch,
    this.required = true,
  });

  final ProcessResult Function(List<String> arguments) runGit;

  /// The branch to push, or null to push whatever git has upstream.
  final String? branch;

  /// Whether a failed push stops the run.
  ///
  /// It does for `delivery publish`: the pull request cannot be opened against
  /// a head the remote has never seen. It does not for `verification publish`,
  /// where verification produces no code and nothing to push is the ordinary
  /// case — what the push there covers is the walk that turned up a fix.
  final bool required;

  List<String> get _arguments => branch == null
      ? const ['push']
      : ['push', '--set-upstream', 'origin', branch!];

  String get _target => branch == null ? 'origin' : 'origin/$branch';

  @override
  Preview preview() => Preview(
    verb: 'push',
    target: _target,
    detail: [
      'git ${_arguments.join(' ')}',
      if (!required) 'nothing to push is not a failure here',
    ].join('; '),
  );

  @override
  Future<Outcome> perform(StepContext context) async {
    final result = runGit(_arguments);
    if (result.exitCode != 0) {
      if (required) {
        throw StateError('git push failed:\n${result.stderr}'.trimRight());
      }
      // Reported, not hidden: the plan said it would push, and a reader is
      // owed the fact that it did not — even where that is allowed.
      return Outcome(
        verb: 'push',
        target: _target,
        detail: 'nothing pushed',
        values: {'pushed': false},
      );
    }
    return Outcome(verb: 'push', target: _target, values: {'pushed': true});
  }
}

/// Opens the pull request, or updates the one already open.
///
/// Its number and URL do not exist until it does, so the preview declares them
/// rather than staying silent.
class PublishPullRequest implements Step {
  PublishPullRequest({
    required this.publisher,
    required this.record,
    required this.body,
    required this.base,
    required this.head,
    required this.dir,
    this.repo,
  });

  final PullRequestPublisher publisher;
  final RequisitionRecord record;

  /// Assembled when this step was built, and not again.
  final AssembledBody body;

  final String base;
  final String head;
  final String dir;
  final String? repo;

  String get _verb => record.isDelivered ? 'update' : 'open';

  String get _target => record.isDelivered
      ? 'pull request #${record.pr}'
      : 'the pull request for "${p.basename(dir)}"';

  @override
  Preview preview() => Preview(
    verb: _verb,
    target: _target,
    // The exact `gh` line is part of the claim: what reaches GitHub is the
    // thing being approved, and a reviewer who cannot see the command cannot
    // judge it.
    detail: [
      'title: ${record.prTitle}',
      'labels: ${record.labels.isEmpty ? '(none)' : record.labels.join(', ')}',
      '${body.lines} lines from ${body.parts.join(' + ')}',
      'issue #${record.issue} referenced, not closed',
      '$head → $base',
      'gh ${publisher.plannedArgs(record, base: base, head: head, repo: repo).join(' ')} '
          '--body-file <body>',
    ].join('; '),
    pending: const ['pr', 'url'],
  );

  @override
  Future<Outcome> perform(StepContext context) async {
    final result = await publisher.publish(
      record,
      body,
      base: base,
      head: head,
      repo: repo,
    );
    if (!result.ok) throw StateError(result.error!);

    return Outcome(
      verb: _verb,
      target: _target,
      values: {'pr': result.number ?? record.pr, 'url': result.url},
    );
  }
}

/// Records the pull request the delivery went to.
///
/// Reads the number from [source] rather than asking GitHub again: a second
/// question could answer differently, and this step is not the one that knows
/// how to ask.
class RecordDelivered implements Step {
  RecordDelivered({
    required this.source,
    required this.record,
    required this.dir,
    required this.base,
    required this.head,
  });

  final Step source;
  final RequisitionRecord record;
  final String dir;
  final String base;
  final String head;

  String get _target => '${p.basename(dir)}/${RequisitionRecord.fileName}';

  @override
  Preview preview() => Preview(
    verb: 'record',
    target: _target,
    detail: '$head → $base',
    pending: const ['pr'],
  );

  @override
  Future<Outcome> perform(StepContext context) async {
    final number = context.outcomeOf(source).values['pr'] as int?;
    if (number != null) {
      record.delivered(pr: number, base: base, head: head).write(dir);
    }
    return Outcome(verb: 'record', target: _target, values: {'pr': number});
  }
}
