/// `macss requisition list` — what exists, and which one is active.
///
/// Reads the workspace on disk. It does **not** run the stage gates: how far a
/// requisition has got is answered by which documents exist, not by whether
/// they pass. Running three gates per row would be slow and could fail for
/// reasons that have nothing to do with listing.
///
/// It changes nothing, so it declares neither `--plan` nor `--apply` and rejects
/// both (ADR 0007 applies to commands that write).
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../specification/workspace.dart';

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
  final bool hasRequisition;
  final bool hasSpecification;
  final bool hasImplementation;
  final bool hasDelivery;
  final bool hasVerification;

  /// The issue carrying it, when it has been published.
  final int? issue;

  const RequisitionEntry({
    required this.folder,
    required this.slug,
    required this.isActive,
    required this.hasRequisition,
    required this.hasSpecification,
    required this.hasImplementation,
    required this.hasDelivery,
    required this.hasVerification,
    this.issue,
  });

  /// How far the work has got, named with the lifecycle's own stages.
  ///
  /// Five of the seven leave an artifact on disk and are therefore observable
  /// without running anything. **`dor` and `dod` are gates, not artifacts**:
  /// knowing either has been met means running it, which this listing
  /// deliberately does not do. So the furthest stage reported is the furthest
  /// one that wrote a file.
  String get stage {
    if (hasVerification) return 'verification';
    if (hasDelivery) return 'delivery';
    if (hasImplementation) return 'implementation';
    if (hasSpecification) return 'specification';
    if (hasRequisition) return 'requisition';
    return 'empty';
  }

  Map<String, dynamic> toJson() => {
        'folder': folder,
        'slug': slug,
        'active': isActive,
        'stage': stage,
        if (issue != null) 'issue': issue,
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

    final entries = [
      for (final folder in folders)
        RequisitionEntry(
          folder: folder,
          slug: _slugOf(folder),
          isActive: folder == activeFolder,
          hasRequisition: _has(base, folder, 'requisition.md'),
          hasSpecification: _has(base, folder, 'specification.md'),
          // The implementation stage writes two artifacts across its phases;
          // either one means it has been entered.
          hasImplementation: _has(base, folder, 'diagnosis.md') ||
              _has(base, folder, 'plan.md'),
          hasDelivery: _has(base, folder, 'delivery.md'),
          hasVerification: _has(base, folder, 'verification.md'),
          issue: _issueOf(base, folder),
        ),
    ];

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

  bool _has(Directory base, String folder, String file) =>
      File(p.join(base.path, folder, file)).existsSync();

  int? _issueOf(Directory base, String folder) {
    final f = File(p.join(base.path, folder, 'issue.yaml'));
    if (!f.existsSync()) return null;
    final m = RegExp(r'^issue:\s*(\d+)\s*$', multiLine: true)
        .firstMatch(f.readAsStringSync());
    return m == null ? null : int.tryParse(m.group(1)!);
  }
}
