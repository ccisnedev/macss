/// `macss requisition list` — what exists, and which one is active.
///
/// Reads the workspace on disk and runs no gate: how far a requisition has got
/// is what the commands that took it there recorded, not something re-derived
/// per row. Running three gates per row would be slow and could fail for
/// reasons that have nothing to do with listing.
///
/// It used to answer the question from which documents existed, which could
/// only ever report the five stages that write a file — `dor` and `dod` are
/// gates and leave no artifact. Now they record what they establish, so the
/// listing reports them without running anything.
///
/// It changes nothing, so it declares neither `--plan` nor `--apply` and rejects
/// both (ADR 0007 applies to commands that write).
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../specification/workspace.dart';
import '../requisition_record.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class RequisitionListInput extends Input {
  RequisitionListInput();

  factory RequisitionListInput.fromCliRequest(CliRequest req) =>
      RequisitionListInput();

  /// Declares no options: it takes none, and any it is given is rejected.
  static const List<CliParam> params = [];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => const {};
}

// ─── Output ─────────────────────────────────────────────────────────────────

/// One requisition, as the listing reports it.
class RequisitionEntry {
  /// The folder on disk: `<YYYYMMDD>-<slug>`.
  final String folder;

  /// What a person types to select it. The date is decoration that orders the
  /// folders; it is not part of the identity.
  final String slug;

  final bool isActive;

  /// How far the work has got, as the commands that took it there recorded.
  ///
  /// Null when the folder carries no readable record. It used to be derived
  /// from which documents were on disk, which could only ever report the five
  /// stages that write a file: `dor` and `dod` are gates, and knowing either
  /// was met meant running it. Now they write what they establish, so the
  /// listing can report them without running anything — and two answers to
  /// "how far has this got?" would be none.
  final RequisitionState? state;

  /// The issue carrying it, when it has been published.
  final int? issue;

  /// The pull request carrying the work, when it has been opened.
  ///
  /// Shown beside the issue because it is the fact `prune` will act on, and a
  /// destructive command whose criterion has never been displayed is one nobody
  /// can audit before running it (ADR 0010).
  final int? pr;

  /// Whether `state.yaml` could be read at all.
  ///
  /// False for a folder that has none, and for one whose `state` is a word
  /// nobody defined. The two are the same answer on purpose: neither is "not
  /// finished yet", and a listing that quietly showed them as live work would
  /// be the trusted-and-wrong failure this listing already refuses for the
  /// dangling pointer.
  final bool isReadable;

  const RequisitionEntry({
    required this.folder,
    required this.slug,
    required this.isActive,
    required this.isReadable,
    this.state,
    this.issue,
    this.pr,
  });

  /// The word shown for how far it has got.
  String get stage => state?.name ?? 'unreadable';

  Map<String, dynamic> toJson() => {
        'folder': folder,
        'slug': slug,
        'active': isActive,
        'state': stage,
        if (issue != null) 'issue': issue,
        if (pr != null) 'pr': pr,
      };

  /// One row.
  ///
  /// The date is **not** shown. It was there to tell two rows apart, and once a
  /// slug names one requisition there are no two rows to tell apart; the order
  /// it gives is already carried by the position, since the folder's date
  /// prefix is what sorts them.
  ///
  /// [disambiguate] brings the folder back for the rows that need it — two
  /// requisitions sharing a slug, which is possible in a project that has them
  /// already. It shows the difference exactly where there is one, instead of a
  /// column that repeats the row order everywhere else.
  String toText({int slugWidth = 0, bool disambiguate = false}) => [
        isActive ? 'active' : '      ',
        slug.padRight(slugWidth),
        if (disambiguate) folder,
        stage,
        if (issue != null) '#$issue',
        if (pr != null) '!$pr',
      ].join('  ').trimRight();
}

class RequisitionListOutput extends Output {
  final List<RequisitionEntry> entries;

  /// Set when the pointer names a folder that is not there. Shown rather than
  /// omitted: a listing that hides a broken state is how it becomes trusted and
  /// wrong.
  final String? danglingPointer;

  RequisitionListOutput({required this.entries, this.danglingPointer});

  @override
  Map<String, dynamic> toJson() => {
        'requisitions': entries.map((e) => e.toJson()).toList(),
        if (danglingPointer != null) 'danglingPointer': danglingPointer,
      };

  @override
  int get exitCode => ExitCode.ok;

  @override
  String? toText() {
    if (entries.isEmpty && danglingPointer == null) {
      return 'No requisitions in this project. Open one with '
          '`macss requisition new <slug> --apply`.';
    }

    final width = entries.fold<int>(
        0, (w, e) => e.slug.length > w ? e.slug.length : w);

    // Slugs that name more than one requisition. Only those rows carry their
    // folder; everywhere else the slug is the identity and nothing else is
    // needed.
    final shared = <String>{
      for (final e in entries)
        if (entries.where((o) => o.slug == e.slug).length > 1) e.slug,
    };

    return [
      ...entries.map((e) => '  ${e.toText(
            slugWidth: width,
            disambiguate: shared.contains(e.slug),
          )}'),
      if (danglingPointer != null)
        '\n  ! the active requisition points at "$danglingPointer", '
            'which is not there',
      if (danglingPointer == null && !entries.any((e) => e.isActive))
        '\n  none is active — select one with '
            '`macss requisition activate <slug> --apply`',
    ].join('\n');
  }
}

// ─── Command ────────────────────────────────────────────────────────────────

class RequisitionListCommand
    implements Command<RequisitionListInput, RequisitionListOutput> {
  @override
  final RequisitionListInput input;

  final String workingDirectory;

  RequisitionListCommand(this.input, {required this.workingDirectory});

  @override
  String? validate() => null;

  @override
  Future<RequisitionListOutput> execute() async {
    // The same resolver every other command uses, so the marked row and the
    // folder the commands act on cannot disagree.
    final active = resolveRequisitionDir(workingDirectory);
    final activeFolder = active == null ? null : p.basename(active);

    final base = Directory(
        p.join(workingDirectory, 'docs', 'requisitions'));
    final folders = base.existsSync()
        ? (base.listSync().whereType<Directory>().map((d) => p.basename(d.path))
            .toList()
          ..sort())
        : <String>[];

    final entries = <RequisitionEntry>[];
    for (final folder in folders) {
      // Read once: whether the record is there and what it says are the same
      // question, and asking twice invites the two answers to disagree.
      final record = RequisitionRecord.read(p.join(base.path, folder));

      entries.add(RequisitionEntry(
        folder: folder,
        slug: _slugOf(folder),
        isActive: folder == activeFolder,
        isReadable: record != null,
        state: record?.state,
        issue: record?.issue,
        pr: record?.pr,
      ));
    }

    // A pointer whose folder is gone resolves to nothing, so no row carries the
    // marker. Saying which folder it named is what makes it fixable.
    final pointed = activeRequisitionPath(workingDirectory);
    final dangling = active == null && pointed != null ? pointed : null;

    return RequisitionListOutput(entries: entries, danglingPointer: dangling);
  }

  String _slugOf(String folder) {
    final m = RegExp(r'^\d{8}-(.+)$').firstMatch(folder);
    return m?.group(1) ?? folder;
  }

}
