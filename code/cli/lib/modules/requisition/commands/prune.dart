/// `macss requisition prune --plan|--apply` — the workspace lets go of what is
/// finished.
///
/// Nothing removed a requisition, so the ratio of noise to signal only grew:
/// `list` showed everything ever opened, and the command whose purpose is to
/// answer *"what is next?"* had stopped answering it.
///
/// **It reads files and asks the platform nothing.** The criterion is the state
/// the gates recorded, not whether GitHub says a branch merged. That is not a
/// shortcut: `dod` is the method's own definition of finished, and the merge
/// only confirms the grant was honoured (ADR 0008 §8). It also expresses what
/// no platform can — a requisition that was **discarded**, superseded or
/// abandoned, which was never delivered and never will be.
///
/// **It destroys, and there is no `git restore` behind it.** `docs/requisitions/`
/// is deliberately unversioned. What makes that safe is not this command's
/// caution but the fact that after the Definition of Done nothing in the folder
/// is unique: the request and the contract are the issue body, the delivery and
/// the evidence are the pull-request body, and the diagnosis and the plan are
/// comments on the issue. The working documents go with the rest on purpose —
/// the code is what the diagnosis and the plan became, and decisions worth
/// keeping are in `adr/`.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../specification/workspace.dart';
import '../requisition_record.dart';

/// The two states that mean a requisition is finished with.
///
/// `done` is the Definition of Done met. `discarded` is the decision that it
/// never will be. Everything between them is live work.
const prunableStates = {RequisitionState.done, RequisitionState.discarded};

// ─── Input ──────────────────────────────────────────────────────────────────

class RequisitionPruneInput extends Input {
  RequisitionPruneInput();

  factory RequisitionPruneInput.fromCliRequest(CliRequest req) =>
      RequisitionPruneInput();

  /// Declares no options of its own: it takes none, and any it is given is
  /// rejected. The three change flags are the SDK's.
  static const List<CliParam> params = [];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => const {};
}

// ─── Steps ──────────────────────────────────────────────────────────────────

/// Removes one finished requisition's folder.
class RemoveRequisition implements Step {
  RemoveRequisition({required this.path, required this.shownAs});

  final String path;
  final String shownAs;

  @override
  Preview preview() => Preview(verb: 'remove', target: shownAs);

  @override
  Future<Outcome> perform(StepContext context) async {
    Directory(path).deleteSync(recursive: true);
    return Outcome(verb: 'remove', target: shownAs);
  }
}

/// Clears the active-requisition pointer.
///
/// A pointer at a folder this command deleted on purpose is exactly the
/// dangling state the listing exists to report, so clearing it is part of the
/// removal rather than a tidy-up afterwards — and it is a step of its own, so
/// the plan says so before it happens.
class ClearActiveRequisition implements Step {
  ClearActiveRequisition(this.pointerPath);

  final String pointerPath;

  @override
  Preview preview() => Preview(
    verb: 'clear',
    target: 'the active requisition pointer',
    detail: 'it names a requisition this removes',
  );

  @override
  Future<Outcome> perform(StepContext context) async {
    final file = File(pointerPath);
    if (file.existsSync()) file.deleteSync();
    return Outcome(verb: 'clear', target: 'the active requisition pointer');
  }
}

// ─── Output ─────────────────────────────────────────────────────────────────

class RequisitionPruneOutput extends Output {
  RequisitionPruneOutput({
    required this.removed,
    this.unreadable = const [],
    this.clearedPointer = false,
  });

  final List<String> removed;

  /// Folders nothing could read. Named rather than counted: "I cannot tell"
  /// and "it is finished" are different answers, and only one of them
  /// authorises destruction.
  final List<String> unreadable;

  final bool clearedPointer;

  @override
  Map<String, dynamic> toJson() => {
    'removed': removed,
    if (unreadable.isNotEmpty) 'unreadable': unreadable,
    'clearedPointer': clearedPointer,
  };

  @override
  int get exitCode => ExitCode.ok;

  @override
  String? toText() => [
    if (removed.isEmpty)
      'Nothing to remove: no requisition is done or discarded.'
    else ...[
      'Removed ${removed.length} finished '
          'requisition${removed.length == 1 ? '' : 's'}:',
      ...removed.map((f) => '  removed  docs/requisitions/$f'),
      if (clearedPointer) '  cleared  the active requisition pointer',
    ],
    if (unreadable.isNotEmpty) ...[
      '',
      'Left alone because nothing could read them:',
      ...unreadable.map((f) => '  unreadable  $f'),
    ],
  ].join('\n');
}

// ─── Command ────────────────────────────────────────────────────────────────

class RequisitionPruneCommand
    implements Command<RequisitionPruneInput, RequisitionPruneOutput> {
  @override
  final RequisitionPruneInput input;

  final String workingDirectory;
  final Approver? approver;
  final DateTime Function()? now;

  RequisitionPruneCommand(
    this.input, {
    required this.workingDirectory,
    this.approver,
    this.now,
  });

  @override
  String? validate() => null;

  /// Folders whose record could not be read, filled by [steps] and reported by
  /// [describe]. They are not a step — nothing is done to them, and that is the
  /// point.
  List<String> _unreadable = const [];

  /// One removal per finished requisition, and the pointer last if it named
  /// any of them.
  ///
  /// Reading the records is the whole decision, and it happens here so the plan
  /// can name every folder before one of them is gone. Nothing about this is
  /// recoverable: `docs/requisitions/` is not versioned, so there is no git
  /// restore behind it.
  @override
  Future<List<Step>> steps() async {
    final base = Directory(p.join(workingDirectory, 'docs', 'requisitions'));
    if (!base.existsSync()) return const [];

    final folders =
        base
            .listSync()
            .whereType<Directory>()
            .map((d) => p.basename(d.path))
            .toList()
          ..sort();

    final finished = <String>[];
    final unreadable = <String>[];
    for (final folder in folders) {
      final record = RequisitionRecord.read(p.join(base.path, folder));
      if (record == null) {
        // "I cannot tell" and "it is finished" are different answers, and only
        // one of them authorises destruction.
        unreadable.add(folder);
        continue;
      }
      if (prunableStates.contains(record.state)) finished.add(folder);
    }
    _unreadable = unreadable;

    final active = activeRequisitionPath(workingDirectory);
    final pointerIsDoomed =
        active != null && finished.any((f) => active.endsWith(f));

    return [
      for (final folder in finished)
        RemoveRequisition(
          path: p.join(base.path, folder),
          shownAs: folder,
        ),
      if (pointerIsDoomed)
        ClearActiveRequisition(
          p.join(workingDirectory, workspaceDirName, activeRequisitionFileName),
        ),
    ];
  }

  @override
  RequisitionPruneOutput describe(Execution execution) =>
      RequisitionPruneOutput(
        removed: [
          for (final o in execution.outcomes)
            if (o.verb == 'remove') o.target,
        ],
        unreadable: _unreadable,
        clearedPointer: execution.outcomes.any((o) => o.verb == 'clear'),
      );
}
