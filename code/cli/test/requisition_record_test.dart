/// `state.yaml` — the requisition's lifecycle record.
///
/// It replaces `issue.yaml`, which held only what the issue needed. The record
/// answers a wider question — how far this requirement has got — and it is the
/// only local fact `prune` will act on, so what it refuses to read matters as
/// much as what it reads.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/modules/requisition/requisition_record.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('macss_record_'));
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  String path() => p.join(dir.path, 'state.yaml');

  group('reading and writing the record', () {
    test('round-trips every field', () {
      const written = RequisitionRecord(
        title: 'The lifecycle is built on one side only',
        prTitle: 'feat(cli)!: the pull-request side of the cycle',
        labels: ['enhancement', 'bug'],
        state: RequisitionState.delivered,
        issue: 56,
        pr: 57,
        base: 'main',
        head: 'feat/the-pull-request-side-of-the-cycle',
      );
      written.write(dir.path);

      final read = RequisitionRecord.read(dir.path)!;
      expect(read.title, written.title);
      expect(read.prTitle, written.prTitle);
      expect(read.labels, written.labels);
      expect(read.state, RequisitionState.delivered);
      expect(read.issue, 56);
      expect(read.pr, 57);
      expect(read.base, 'main');
      expect(read.head, written.head);
    });

    test('a freshly opened requisition carries only a title and a state', () {
      const RequisitionRecord(title: 'x', state: RequisitionState.opened)
          .write(dir.path);

      final read = RequisitionRecord.read(dir.path)!;
      expect(read.state, RequisitionState.opened);
      expect(read.issue, isNull);
      expect(read.pr, isNull);
      expect(read.prTitle, isNull);
      expect(read.labels, isEmpty);
    });

    test('the file is state.yaml, beside the documents it describes', () {
      const RequisitionRecord(title: 'x', state: RequisitionState.opened)
          .write(dir.path);
      expect(File(path()).existsSync(), isTrue);
    });

    test('no file at all reads as nothing', () {
      expect(RequisitionRecord.read(dir.path), isNull);
    });
  });

  group('the list of states is closed', () {
    test('every state in the ladder round-trips by name', () {
      for (final state in RequisitionState.values) {
        RequisitionRecord(title: 'x', state: state).write(dir.path);
        expect(RequisitionRecord.read(dir.path)!.state, state,
            reason: '${state.name} did not survive the round trip');
      }
    });

    /// A folder whose state is a word nobody defined is **broken**, not "not
    /// finished yet". `discarded` is typed by hand, and a typo that reads as
    /// unfinished would be a folder that never goes away for a reason nobody
    /// can see — the failure this record exists to make visible.
    test('a state outside the ladder is not a record', () {
      File(path()).writeAsStringSync('title: "x"\nstate: dsicarded\n');
      expect(RequisitionRecord.read(dir.path), isNull);
    });

    test('a record with no state at all is not a record', () {
      File(path()).writeAsStringSync('title: "x"\n');
      expect(RequisitionRecord.read(dir.path), isNull);
    });
  });

  group('the ladder has an order, and discarded is off it', () {
    test('the seven rungs run forwards', () {
      expect(RequisitionState.opened.isBefore(RequisitionState.published),
          isTrue);
      expect(RequisitionState.specified.isBefore(RequisitionState.ready),
          isTrue);
      expect(RequisitionState.verified.isBefore(RequisitionState.done), isTrue);
      expect(RequisitionState.done.isBefore(RequisitionState.ready), isFalse);
    });

    /// A gate that passes must never bring an abandoned requisition back. It is
    /// the reason `discarded` is declared last: from anywhere else in the enum
    /// it would read as "earlier than" something, and a passing `dor check`
    /// would quietly put it back on the ladder.
    test('discarded is earlier than nothing', () {
      for (final state in RequisitionState.values) {
        expect(RequisitionState.discarded.isBefore(state), isFalse,
            reason: 'discarded read as earlier than ${state.name}');
      }
    });
  });

  group('a transition carries the fact it rests on', () {
    /// The state and the number are written in one act, so a record cannot say
    /// `published` while nothing names the issue — or carry an issue number
    /// while still claiming to be `opened`.
    test('publishing records the issue and the state together', () {
      const opened =
          RequisitionRecord(title: 'x', state: RequisitionState.opened);

      final published = opened.published(56);

      expect(published.state, RequisitionState.published);
      expect(published.issue, 56);
      expect(published.title, 'x');
    });

    test('delivering records the pull request, its base and its head', () {
      const ready = RequisitionRecord(
          title: 'x', state: RequisitionState.ready, issue: 56);

      final delivered = ready.delivered(pr: 57, base: 'main', head: 'feat/x');

      expect(delivered.state, RequisitionState.delivered);
      expect(delivered.pr, 57);
      expect(delivered.base, 'main');
      expect(delivered.head, 'feat/x');
      expect(delivered.issue, 56, reason: 'the issue survives the transition');
    });

    test('a gate advances the state and nothing else', () {
      const specified = RequisitionRecord(
          title: 'x', state: RequisitionState.specified, issue: 56);

      final ready = specified.at(RequisitionState.ready);

      expect(ready.state, RequisitionState.ready);
      expect(ready.issue, 56);
    });
  });
}
