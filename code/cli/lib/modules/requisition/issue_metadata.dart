/// `issue.yaml` — the tool's metadata for a requisition's issue.
///
/// It lives beside `requisition.md` and `specification.md` rather than in
/// `.macss/`, because it carries fields a person edits: the title and the
/// labels. The requisition folder is self-contained — everything about one
/// requirement lives together, reads together and moves together.
///
/// `repo` is deliberately absent: `gh` infers it from the directory, the same
/// way `gh pr list` does. It was only ever needed when one specification could
/// derive issues into several repositories, which one-requirement-one-issue
/// removes.
///
/// `lang` is absent for the same kind of reason: the project declares its
/// language once, in `.macss/config.yaml`. A copy here would be a second
/// answer, free to drift from the first — and two answers is none.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

class IssueMetadata {
  final String title;
  final List<String> labels;

  /// The published issue number, written back by `publish`. Null until then —
  /// which is how the DoR knows the requisition has not been published yet.
  final int? issue;

  const IssueMetadata({
    required this.title,
    this.labels = const [],
    this.issue,
  });

  bool get isPublished => issue != null;

  static String fileName = 'issue.yaml';

  static String pathIn(String requisitionDir) =>
      p.join(requisitionDir, fileName);

  static IssueMetadata? read(String requisitionDir) {
    final file = File(pathIn(requisitionDir));
    if (!file.existsSync()) return null;

    final doc = loadYaml(file.readAsStringSync());
    if (doc is! Map) return null;

    final rawLabels = doc['labels'];
    return IssueMetadata(
      title: '${doc['title'] ?? ''}',
      labels: rawLabels is List
          ? rawLabels.map((l) => '$l').where((l) => l.isNotEmpty).toList()
          : const [],
      issue: doc['issue'] is int ? doc['issue'] as int : null,
    );
  }

  void write(String requisitionDir) {
    File(pathIn(requisitionDir)).writeAsStringSync(toYaml());
  }

  String toYaml() => [
        '# macss — issue metadata for this requisition.',
        '# Edit the title and labels by hand; `issue` is written by publish.',
        '# The repository is not here: gh infers it from the directory.',
        'title: "${title.replaceAll('"', r'\"')}"',
        'labels: [${labels.join(', ')}]',
        if (issue != null) 'issue: $issue',
        '',
      ].join('\n');

  IssueMetadata withIssue(int number) => IssueMetadata(
        title: title,
        labels: labels,
        issue: number,
      );
}
