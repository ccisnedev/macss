/// Publishing a requisition: the issue is the projection of the local documents.
///
/// The issue body is **assembled**, never hand-authored. It is created carrying
/// the request as soon as the Product Owner delivers it, and updated with the
/// contract once the specification is written — so the requirement has a
/// consultable home from day one and the whole path reads in one place.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'requisition_record.dart';

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

/// GitHub rejects a body over this many characters.
///
/// Checked here rather than in a gate: `check` validates one document, while
/// the body is the assembly of two, so no single check can see the total. And
/// this is a platform number, not a methodology criterion — putting it in the
/// Definition of Ready would tie the method to one vendor's limit.
const githubBodyLimit = 65536;

/// The result of assembling a body, so the caller can preview or publish it.
class AssembledBody {
  final String content;
  final List<String> parts;

  const AssembledBody(this.content, this.parts);

  int get length => content.length;
  bool get exceedsLimit => length > githubBodyLimit;
  int get lines => content.split('\n').length;
}

/// Assembles the issue body from whatever documents exist, in reading order:
/// the request first, then the contract.
AssembledBody assembleBody(String requisitionDir) {
  final parts = <String>[];
  final sections = <String>[];

  for (final name in const ['requisition.md', 'specification.md']) {
    final file = File(p.join(requisitionDir, name));
    if (!file.existsSync()) continue;
    final content = file.readAsStringSync().trim();
    if (content.isEmpty) continue;
    parts.add(name);
    sections.add(content);
  }

  return AssembledBody(sections.join('\n\n---\n\n'), parts);
}

/// Creates or updates the issue for [requisitionDir].
///
/// `gh` resolves the repository from the working directory, the way `gh pr
/// list` does. An explicit [repo] overrides it for the rare cross-repository
/// case.
class IssuePublisher {
  final ProcessRunner runProcess;

  const IssuePublisher({required this.runProcess});

  /// The `gh` invocation that would run, without the body file.
  ///
  /// The two subcommands do not share a label flag. `gh issue create` takes
  /// `--label`; `gh issue edit` rejects it and takes `--add-label`, which adds
  /// without removing — so labels put on the issue by hand survive a
  /// republish. Using `--label` for both is what shipped, and it made every
  /// update fail once a requisition declared any label.
  List<String> plannedArgs(RequisitionRecord meta, {String? repo}) => [
        'issue',
        if (meta.isPublished) ...['edit', '${meta.issue}'] else 'create',
        if (repo != null) ...['--repo', repo],
        '--title',
        meta.title,
        for (final label in meta.labels)
          ...[meta.isPublished ? '--add-label' : '--label', label],
      ];

  /// Runs `gh` with the assembled body written to a temp file.
  ///
  /// Returns the issue number on create, or the existing one on edit.
  Future<PublishResult> publish(
    RequisitionRecord meta,
    AssembledBody body, {
    String? repo,
  }) async {
    final bodyFile = File(p.join(
      Directory.systemTemp.createTempSync('macss_issue_').path,
      'body.md',
    ))
      ..writeAsStringSync(body.content);

    try {
      final result = await runProcess(
        'gh',
        [...plannedArgs(meta, repo: repo), '--body-file', bodyFile.path],
      );
      if (result.exitCode != 0) {
        return PublishResult.failure(
          'gh ${meta.isPublished ? 'issue edit' : 'issue create'} failed:\n'
          '${result.stderr}'.trimRight(),
        );
      }

      final output = result.stdout.toString().trim();
      return PublishResult.success(
        url: output,
        number: meta.issue ?? _numberFromUrl(output),
      );
    } finally {
      bodyFile.parent.deleteSync(recursive: true);
    }
  }

  /// `https://github.com/owner/repo/issues/42` → 42.
  static int? _numberFromUrl(String url) {
    final match = RegExp(r'/(\d+)\s*$').firstMatch(url);
    return match == null ? null : int.tryParse(match.group(1)!);
  }
}

class PublishResult {
  final bool ok;
  final String? url;
  final int? number;
  final String? error;

  const PublishResult.success({this.url, this.number})
      : ok = true,
        error = null;

  const PublishResult.failure(this.error)
      : ok = false,
        url = null,
        number = null;
}
