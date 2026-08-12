/// `macss requisition prune` — the workspace lets go of what is finished.
///
/// The only destructive command in this CLI, and the only one with nothing
/// behind it: `docs/requisitions/` is not versioned, so there is no
/// `git restore` after this. Everything here is about what it refuses to touch.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/modules/requisition/commands/prune.dart';
import 'package:macss_cli/modules/specification/workspace.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('macss_prune_'));
  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Directory folder(String name) =>
      Directory(p.join(root.path, 'docs', 'requisitions', name));

  void make(String name, {String? state, bool documents = true}) {
    final dir = folder(name)..createSync(recursive: true);
    if (documents) {
      File(p.join(dir.path, 'requisition.md')).writeAsStringSync('# R\n');
      File(p.join(dir.path, 'diagnosis.md')).writeAsStringSync('# D\n');
      File(p.join(dir.path, 'plan.md')).writeAsStringSync('# P\n');
    }
    if (state != null) {
      File(p.join(dir.path, 'state.yaml'))
          .writeAsStringSync('title: "t"\nstate: $state\nissue: 1\n');
    }
  }

  Future<RequisitionPruneOutput> prune({bool apply = true}) =>
      RequisitionPruneCommand(
        RequisitionPruneInput(
          flags: apply
              ? const ChangeFlags(apply: true, autoapprove: true)
              : const ChangeFlags(plan: true),
        ),
        workingDirectory: root.path,
        now: () => DateTime(2026, 8, 12),
      ).execute();

  group('what goes', () {
    test('a requirement that is done, and one that was discarded', () async {
      make('20260801-finished', state: 'done');
      make('20260802-abandoned', state: 'discarded');

      await prune();

      expect(folder('20260801-finished').existsSync(), isFalse);
      expect(folder('20260802-abandoned').existsSync(), isFalse);
    });

    /// The working documents go with the rest, and that is the point. The code
    /// is the materialisation of the diagnosis and the plan; decisions worth
    /// keeping are in `adr/`. What the folder held that was unique is published
    /// — the request and contract on the issue, the delivery and evidence on the
    /// pull request, the diagnosis and plan as issue comments.
    test('the working documents go with it', () async {
      make('20260801-finished', state: 'done');

      await prune();

      expect(folder('20260801-finished').existsSync(), isFalse);
    });
  });

  group('what stays', () {
    test('every state that is not finished', () async {
      for (final state in const [
        'opened',
        'published',
        'specified',
        'ready',
        'delivered',
        'verified',
      ]) {
        make('20260801-$state', state: state);
      }

      await prune();

      for (final state in const [
        'opened',
        'published',
        'specified',
        'ready',
        'delivered',
        'verified',
      ]) {
        expect(folder('20260801-$state').existsSync(), isTrue,
            reason: '$state is live work');
      }
    });

    /// A folder nothing can read is not a folder anything may delete. "I cannot
    /// tell" and "it is finished" are different answers, and only one of them
    /// authorises destruction.
    test('a folder with no record', () async {
      make('20260801-broken', state: null);

      final out = await prune();

      expect(folder('20260801-broken').existsSync(), isTrue);
      expect(out.message, contains('unreadable'));
    });

    test('a record whose state is a word nobody defined', () async {
      make('20260801-typo', state: 'dsicarded');

      await prune();

      expect(folder('20260801-typo').existsSync(), isTrue);
    });
  });

  group('the convention', () {
    test('--plan names every folder that would go, and removes none', () async {
      make('20260801-finished', state: 'done');
      make('20260802-live', state: 'ready');

      final out = await prune(apply: false);

      expect(folder('20260801-finished').existsSync(), isTrue);
      final plan = File(out.planPath!).readAsStringSync();
      expect(plan, contains('20260801-finished'));
      expect(plan, isNot(contains('20260802-live')));
    });

    test('with neither flag it refuses', () {
      final cmd = RequisitionPruneCommand(
        RequisitionPruneInput(flags: const ChangeFlags()),
        workingDirectory: root.path,
      );

      expect(cmd.validate(), contains('Choose --plan or --apply'));
    });

    test('nothing to remove says so and writes no plan', () async {
      make('20260801-live', state: 'ready');

      final out = await prune(apply: false);

      expect(out.removed, isEmpty);
      expect(out.planPath, isNull);
    });
  });

  /// Otherwise pruning manufactures exactly the dangling state the listing
  /// exists to report, and the next command fails pointing at a folder this one
  /// deleted on purpose.
  test('removing the active requisition clears the pointer', () async {
    make('20260801-finished', state: 'done');
    writeActiveRequisition(root.path,
        slug: 'finished',
        relDir: 'docs/requisitions/20260801-finished',
        isoDate: '2026-08-01');

    await prune();

    expect(activeRequisitionPath(root.path), isNull);
  });
}
