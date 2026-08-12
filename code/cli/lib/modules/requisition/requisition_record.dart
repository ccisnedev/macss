/// `state.yaml` — the requisition's lifecycle record.
///
/// It lives beside `requisition.md` and the rest rather than in `.macss/`,
/// because it carries fields a person edits: the two titles and the labels. The
/// requisition folder is self-contained — everything about one requirement lives
/// together, reads together and moves together.
///
/// It replaces `issue.yaml`, which recorded only the issue and therefore could
/// not say whether the work had been delivered, verified or abandoned. That gap
/// is why nothing could ever decide a requisition was finished, and why the
/// workspace only ever grew.
///
/// `repo` is deliberately absent: `gh` infers it from the directory, the way
/// `gh pr list` does. `lang` is absent for a related reason — the project
/// declares its language once, in `.macss/config.yaml`, and a copy here would be
/// a second answer free to drift from the first.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// How far a requisition has got.
///
/// Every state is written by a command that somebody already runs for its own
/// reason, except [discarded], which is a decision rather than an observation
/// and is therefore typed by hand. A state nobody writes would be an
/// instruction, and ADR 0006 rules out instruction alone.
///
/// There is no `implementation`: the phase produces a diagnosis and a plan, and
/// no command attests either.
enum RequisitionState {
  /// `requisition new` — the folder and the form exist.
  opened,

  /// `requisition publish` — the request has an issue.
  published,

  /// `specification publish` — the contract is on that issue.
  specified,

  /// `dor check` passed. The issue body is frozen from here.
  ready,

  /// `delivery publish` — the work has a pull request.
  delivered,

  /// `verification publish` — the evidence is on that pull request.
  verified,

  /// `dod check` passed. The requirement is finished.
  done,

  /// Abandoned or superseded. It was never delivered and never will be.
  ///
  /// **Declared last on purpose.** The seven before it are a ladder and their
  /// order is meaningful — [isBefore] reads it. This one is not a rung: it
  /// leaves the ladder. Last is the only position from which it is never
  /// "earlier than" anything, so a gate that passes on a discarded requisition
  /// cannot bring it back to life.
  discarded,
}

extension RequisitionLadder on RequisitionState {
  /// Whether this state comes earlier in the ladder than [other].
  ///
  /// The gates use it to advance and never to retreat: passing `dor check` on
  /// something already delivered must not put it back to `ready`, because the
  /// state records that a gate was passed, not that it would pass now.
  bool isBefore(RequisitionState other) => index < other.index;
}

class RequisitionRecord {
  /// The issue's title, in the project's language.
  final String title;

  /// The pull request's title: Conventional Commits, and English in every
  /// project (ADR 0008 §3 keeps commit messages English whatever language the
  /// documents are in). It is a different string from [title], not a copy —
  /// issue #24 is *"El idioma se declara una vez"* and the pull request that
  /// delivered it is *"feat(language)!: the project declares its language
  /// once"*. Null until somebody writes it.
  final String? prTitle;

  final List<String> labels;

  final RequisitionState state;

  /// Written by `requisition publish`, alongside the state it justifies.
  final int? issue;

  /// Written by `delivery publish`, with the branches it was opened between.
  final int? pr;
  final String? base;
  final String? head;

  const RequisitionRecord({
    required this.title,
    required this.state,
    this.prTitle,
    this.labels = const [],
    this.issue,
    this.pr,
    this.base,
    this.head,
  });

  bool get isPublished => issue != null;
  bool get isDelivered => pr != null;

  static const fileName = 'state.yaml';

  static String pathIn(String requisitionDir) =>
      p.join(requisitionDir, fileName);

  /// The record in [requisitionDir], or null when there is none **or when what
  /// is there cannot be read as one**.
  ///
  /// The two are deliberately the same answer. A folder whose `state` is a word
  /// nobody defined is broken, not unfinished, and the caller reports it as
  /// unreadable rather than quietly treating it as live work — which for
  /// `prune` would be a folder that never goes away for a reason nobody can see.
  static RequisitionRecord? read(String requisitionDir) {
    final file = File(pathIn(requisitionDir));
    if (!file.existsSync()) return null;

    final doc = loadYaml(file.readAsStringSync());
    if (doc is! Map) return null;

    final state = _stateNamed(doc['state']);
    if (state == null) return null;

    final rawLabels = doc['labels'];
    return RequisitionRecord(
      title: '${doc['title'] ?? ''}',
      prTitle: _stringOrNull(doc['pr_title']),
      labels: rawLabels is List
          ? rawLabels.map((l) => '$l').where((l) => l.isNotEmpty).toList()
          : const [],
      state: state,
      issue: doc['issue'] is int ? doc['issue'] as int : null,
      pr: doc['pr'] is int ? doc['pr'] as int : null,
      base: _stringOrNull(doc['base']),
      head: _stringOrNull(doc['head']),
    );
  }

  void write(String requisitionDir) {
    File(pathIn(requisitionDir)).writeAsStringSync(toYaml());
  }

  String toYaml() => [
        '# macss — the lifecycle record for this requisition.',
        '# Edit the titles and labels by hand; every other key is written by a '
            'command.',
        '# The repository is not here: gh infers it from the directory.',
        'title: "${_escaped(title)}"',
        if (prTitle != null) 'pr_title: "${_escaped(prTitle!)}"',
        'labels: [${labels.join(', ')}]',
        'state: ${state.name}',
        if (issue != null) 'issue: $issue',
        if (pr != null) 'pr: $pr',
        if (base != null) 'base: $base',
        if (head != null) 'head: $head',
        '',
      ].join('\n');

  /// The issue exists, and the record says so in the same act that records its
  /// number. Written together so the two cannot disagree.
  RequisitionRecord published(int number) =>
      _copyWith(state: RequisitionState.published, issue: number);

  /// The pull request exists, with the branches it was opened between.
  RequisitionRecord delivered({
    required int pr,
    required String base,
    required String head,
  }) =>
      _copyWith(
        state: RequisitionState.delivered,
        pr: pr,
        base: base,
        head: head,
      );

  /// Advances the state and nothing else — what a gate records when it passes.
  RequisitionRecord at(RequisitionState state) => _copyWith(state: state);

  RequisitionRecord _copyWith({
    RequisitionState? state,
    String? prTitle,
    int? issue,
    int? pr,
    String? base,
    String? head,
  }) =>
      RequisitionRecord(
        title: title,
        prTitle: prTitle ?? this.prTitle,
        labels: labels,
        state: state ?? this.state,
        issue: issue ?? this.issue,
        pr: pr ?? this.pr,
        base: base ?? this.base,
        head: head ?? this.head,
      );

  static RequisitionState? _stateNamed(Object? value) {
    if (value is! String) return null;
    for (final state in RequisitionState.values) {
      if (state.name == value) return state;
    }
    return null;
  }

  static String? _stringOrNull(Object? value) {
    if (value == null) return null;
    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }

  static String _escaped(String value) => value.replaceAll('"', r'\"');
}
