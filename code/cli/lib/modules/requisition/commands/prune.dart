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
  final ChangeFlags flags;

  RequisitionPruneInput({required this.flags});

  factory RequisitionPruneInput.fromCliRequest(CliRequest req) =>
      RequisitionPruneInput(flags: ChangeFlags.fromCliRequest(req));

  static final List<CliParam> params = [...ChangeFlags.params];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {
        'plan': flags.plan,
        'apply': flags.apply,
        'autoapprove': flags.autoapprove,
      };
}

// ─── Output ─────────────────────────────────────────────────────────────────

class RequisitionPruneOutput extends Output {
  final String message;
  final List<String> removed;
  final String? planPath;
  final bool blocked;

  RequisitionPruneOutput({
    required this.message,
    this.removed = const [],
    this.planPath,
    this.blocked = false,
  });

  @override
  Map<String, dynamic> toJson() =>
      {'message': message, 'removed': removed, 'planPath': planPath};

  @override
  int get exitCode => blocked ? ExitCode.genericError : ExitCode.ok;

  @override
  String? toText() => message;
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
  String? validate() => input.flags.validate();

  @override
  Future<RequisitionPruneOutput> execute() async {
    final base = Directory(p.join(workingDirectory, 'docs', 'requisitions'));
    if (!base.existsSync()) {
      return RequisitionPruneOutput(
          message: 'No requisitions in this project.');
    }

    final folders = base
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
        // one of them authorises destruction. Named rather than counted, so a
        // folder is never left out of the report for being unreadable.
        unreadable.add(folder);
        continue;
      }
      if (prunableStates.contains(record.state)) finished.add(folder);
    }

    if (finished.isEmpty) {
      return RequisitionPruneOutput(
        message: [
          'Nothing to remove: no requisition is done or discarded.',
          if (unreadable.isNotEmpty) ...[
            '',
            'Left alone because nothing could read them:',
            ...unreadable.map((f) => '  unreadable  $f'),
          ],
        ].join('\n'),
      );
    }

    final decision = await ChangeGate(
      flags: input.flags,
      approver: approver,
      now: now,
    ).decide(
      command: 'requisition prune',
      workingDirectory: workingDirectory,
      body: [
        'would remove ${finished.length} finished '
            'requisition${finished.length == 1 ? '' : 's'}, with every document '
            'in them:',
        '',
        ...finished.map((f) => '  remove   docs/requisitions/$f'),
        if (unreadable.isNotEmpty) ...[
          '',
          'Left alone because nothing could read them:',
          ...unreadable.map((f) => '  keep     docs/requisitions/$f '
              '(unreadable)'),
        ],
        '',
        'This is not recoverable: docs/requisitions/ is not versioned, so there '
        'is no git restore behind it. What each folder held is published — the '
        'request and contract on its issue, the delivery and evidence on its '
        'pull request, the diagnosis and plan as issue comments.',
      ].join('\n'),
    );

    if (!decision.proceed) {
      return RequisitionPruneOutput(
        message: decision.message!,
        planPath: decision.planPath,
        blocked: decision.blocked,
      );
    }

    final active = activeRequisitionPath(workingDirectory);
    final steps = <String>[];
    for (final folder in finished) {
      Directory(p.join(base.path, folder)).deleteSync(recursive: true);
      steps.add('  removed  docs/requisitions/$folder');
    }

    // A pointer at a folder this command deleted on purpose is exactly the
    // dangling state the listing exists to report. Clearing it is part of the
    // removal, not a tidy-up afterwards.
    if (active != null && finished.any((f) => active.endsWith(f))) {
      File(p.join(workingDirectory, workspaceDirName, activeRequisitionFileName))
          .deleteSync();
      steps.add('  cleared  the active requisition pointer');
    }

    return RequisitionPruneOutput(
      removed: finished,
      message: [
        'Removed ${finished.length} finished '
            'requisition${finished.length == 1 ? '' : 's'}:',
        ...steps,
        if (unreadable.isNotEmpty) ...[
          '',
          'Left alone because nothing could read them:',
          ...unreadable.map((f) => '  unreadable  $f'),
        ],
      ].join('\n'),
    );
  }
}
