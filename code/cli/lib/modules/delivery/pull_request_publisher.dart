/// Publishing a delivery: the pull request is the projection of the local
/// documents, exactly as the issue is on the other side.
///
/// There is no `macss pr` module for the reason there is no `macss issue` one —
/// the pull request is a **consequence** of publishing the delivery, not an
/// artifact somebody composes (ADR 0008 §4).
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../requisition/publisher.dart';
import '../requisition/requisition_record.dart';

/// Creates or updates the pull request for a requisition.
class PullRequestPublisher {
  final ProcessRunner runProcess;

  const PullRequestPublisher({required this.runProcess});

  /// The `gh` invocation that would run, without the body file.
  ///
  /// `gh pr create` takes `--label`; `gh pr edit` rejects it and takes
  /// `--add-label`, which adds without removing — so labels put on by hand
  /// survive a republish. This is the same asymmetry `gh issue` has, and using
  /// one flag for both is what made every issue update fail once a requisition
  /// declared a label. It was waiting here too.
  ///
  /// `--base` and `--head` have no counterpart on the issue side: an issue is
  /// not opened between two branches.
  /// [base] and [head] are read from git at publish time rather than from the
  /// record: the record stores them **afterwards**, as the fact the transition
  /// produced. Taking them from the record here would mean an earlier publish
  /// deciding which branches a later one goes between.
  List<String> plannedArgs(
    RequisitionRecord record, {
    required String base,
    required String head,
    String? repo,
  }) =>
      [
        'pr',
        if (record.isDelivered) ...['edit', '${record.pr}'] else 'create',
        if (repo != null) ...['--repo', repo],
        if (!record.isDelivered) ...['--base', base, '--head', head],
        '--title',
        // The pull request carries `pr_title`, never the issue's. They differ in
        // form and in language: the issue is titled in the project's language,
        // and a Conventional Commits title is a commit message, which ADR 0008
        // §3 keeps English in every project.
        record.prTitle ?? '',
        for (final label in record.labels)
          ...[record.isDelivered ? '--add-label' : '--label', label],
      ];

  Future<PublishResult> publish(
    RequisitionRecord record,
    AssembledBody body, {
    required String base,
    required String head,
    String? repo,
  }) async {
    final bodyFile = File(p.join(
      Directory.systemTemp.createTempSync('macss_pr_').path,
      'body.md',
    ))
      ..writeAsStringSync(body.content);

    try {
      final result = await runProcess(
        'gh',
        [
          ...plannedArgs(record, base: base, head: head, repo: repo),
          '--body-file',
          bodyFile.path,
        ],
      );
      if (result.exitCode != 0) {
        return PublishResult.failure(
          'gh ${record.isDelivered ? 'pr edit' : 'pr create'} failed:\n'
          '${result.stderr}'.trimRight(),
        );
      }

      final output = result.stdout.toString().trim();
      return PublishResult.success(
        url: output,
        number: record.pr ?? _numberFromUrl(output),
      );
    } finally {
      bodyFile.parent.deleteSync(recursive: true);
    }
  }

  /// `https://github.com/owner/repo/pull/57` → 57.
  static int? _numberFromUrl(String url) {
    final match = RegExp(r'/(\d+)\s*$').firstMatch(url);
    return match == null ? null : int.tryParse(match.group(1)!);
  }
}

/// The line that points the pull request at the issue it answers.
///
/// A plain reference, never `Closes #N`. An issue may deliberately outlive the
/// pull request that answered it — #44 is open on purpose with its work merged
/// — and auto-closing would fight a method that allows it. Closing is a human
/// act, taken when the requirement is finished rather than when a branch lands.
String issueReference(int issue) => 'Requirement: #$issue';
