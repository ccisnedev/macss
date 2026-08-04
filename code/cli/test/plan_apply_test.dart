import 'dart:io';

import 'package:test/test.dart';

import 'package:macss_cli/src/plan_apply.dart';

import 'support/memory_sink.dart';

/// The convention itself, apart from any command that uses it.
///
/// `ConsoleApprover` had no test, and the gap showed: `stdin.hasTerminal` was
/// treated as sufficient proof that someone could answer. It is not — a piped
/// process can report a terminal and then throw on the read — and a smoke run
/// of `macss project adopt --apply` exited 255 with a stack trace where it
/// should have refused.
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('macss_plan_apply_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  DateTime clock() => DateTime(2026, 8, 4, 9, 30, 15);

  group('ChangeFlags', () {
    test('neither flag is a usage error naming both ways out', () {
      final error = const ChangeFlags().validate();

      expect(error, contains('--plan'));
      expect(error, contains('--apply'));
      expect(error, contains('does not decide for you'));
    });

    test('both flags refuse to pick one', () {
      expect(const ChangeFlags(plan: true, apply: true).validate(),
          contains('Choose one'));
    });

    test('--autoapprove without --apply authorizes nothing', () {
      expect(const ChangeFlags(plan: true, autoapprove: true).validate(),
          contains('authorizes nothing'));
    });

    test('the legal combinations pass', () {
      expect(const ChangeFlags(plan: true).validate(), isNull);
      expect(const ChangeFlags(apply: true).validate(), isNull);
      expect(const ChangeFlags(apply: true, autoapprove: true).validate(),
          isNull);
    });

    test('--plan is declared, so it can be typed', () {
      // It used to be "the default, and so not declared", which meant every
      // document telling someone to type it was telling them to fail.
      expect(ChangeFlags.params.map((p) => p.name),
          containsAll(['plan', 'apply', 'autoapprove']));
    });
  });

  group('ConsoleApprover', () {
    test('a yes approves', () async {
      final out = MemorySink();
      final approver = ConsoleApprover(
        out: out.sink,
        hasTerminal: () => true,
        readLine: () => 'y',
      );

      expect(await approver('Plan — something'), isTrue);
      expect(await out.text(), contains('Plan — something'));
      expect(await out.text(), contains('Apply this plan?'));
    });

    test('anything else refuses — the default is not to write', () async {
      for (final answer in const ['', 'n', 'no', 'sure', 'Y E S']) {
        final approver = ConsoleApprover(
          out: MemorySink().sink,
          hasTerminal: () => true,
          readLine: () => answer,
        );

        expect(await approver('Plan'), isFalse, reason: 'answered "$answer"');
      }
    });

    test('no terminal means nobody to ask', () {
      final approver = ConsoleApprover(
        out: MemorySink().sink,
        hasTerminal: () => false,
        readLine: () => 'y',
      );

      expect(approver('Plan'), throwsA(isA<NoApproverAvailable>()));
    });

    // The defect the smoke run found. Windows reports a terminal for a piped
    // process and then fails the read.
    test('a terminal that cannot be read from means the same thing', () {
      final approver = ConsoleApprover(
        out: MemorySink().sink,
        hasTerminal: () => true,
        readLine: () => throw const StdinException('handle is invalid'),
      );

      expect(approver('Plan'), throwsA(isA<NoApproverAvailable>()));
    });

    test('the refusal names the flag that resolves it', () {
      expect(const NoApproverAvailable().message, contains('--autoapprove'));
    });
  });

  group('PlanFile', () {
    test('a plan reads on its own, away from the terminal', () {
      final path = PlanFile.write(
        workingDirectory: tempDir.path,
        command: 'project adopt',
        body: 'would create CHANGELOG.md',
        now: clock(),
      );

      final plan = File(path).readAsStringSync();
      expect(plan, contains('macss project adopt'));
      expect(plan, contains('would create CHANGELOG.md'));
      expect(plan, contains('Nothing was changed'));
      expect(plan, contains('--apply'));
      expect(plan, contains('2026-08-04'));
    });

    test('lands under the MACSS workspace, which is git-ignored', () {
      final path = PlanFile.write(
        workingDirectory: tempDir.path,
        command: 'requisition publish',
        body: 'x',
        now: clock(),
      );

      expect(path, contains('.macss'));
      expect(path, contains('plans'));
      expect(path, endsWith('requisition-publish.md'));
    });

    test('the stamp keeps successive plans apart, so two runs compare', () {
      final first = PlanFile.write(
        workingDirectory: tempDir.path,
        command: 'project adopt',
        body: 'a',
        now: DateTime(2026, 8, 4, 9, 30, 15),
      );
      final second = PlanFile.write(
        workingDirectory: tempDir.path,
        command: 'project adopt',
        body: 'b',
        now: DateTime(2026, 8, 4, 9, 30, 16),
      );

      expect(second, isNot(first));
      expect(File(first).readAsStringSync(), contains('a'));
      expect(File(second).readAsStringSync(), contains('b'));
    });
  });

  group('ChangeGate', () {
    Future<ChangeDecision> decide(ChangeFlags flags, {Approver? approver}) =>
        ChangeGate(flags: flags, approver: approver, now: clock).decide(
          command: 'project adopt',
          workingDirectory: tempDir.path,
          body: 'would create CHANGELOG.md',
        );

    test('--plan writes the file and does not proceed', () async {
      final decision = await decide(const ChangeFlags(plan: true));

      expect(decision.proceed, isFalse);
      expect(decision.blocked, isFalse);
      expect(File(decision.planPath!).existsSync(), isTrue);
    });

    test('--apply --autoapprove proceeds without asking', () async {
      var asked = false;
      final decision = await decide(
        const ChangeFlags(apply: true, autoapprove: true),
        approver: (_) async {
          asked = true;
          return true;
        },
      );

      expect(asked, isFalse);
      expect(decision.proceed, isTrue);
      expect(decision.planPath, isNull, reason: 'apply writes no plan file');
    });

    test('a refusal blocks, so a script cannot read it as a change', () async {
      final decision = await decide(
        const ChangeFlags(apply: true),
        approver: (_) async => false,
      );

      expect(decision.proceed, isFalse);
      expect(decision.blocked, isTrue);
    });

    test('nobody to ask blocks and explains', () async {
      final decision = await decide(
        const ChangeFlags(apply: true),
        approver: (_) async => throw const NoApproverAvailable(),
      );

      expect(decision.proceed, isFalse);
      expect(decision.blocked, isTrue);
      expect(decision.message, contains('--autoapprove'));
    });

    // Rule 6: one computation, rendered once.
    test('the approver sees what the plan file would have said', () async {
      var shown = '';
      await decide(
        const ChangeFlags(apply: true),
        approver: (plan) async {
          shown = plan;
          return true;
        },
      );
      final planned = await decide(const ChangeFlags(plan: true));
      final written = File(planned.planPath!).readAsStringSync();

      expect(shown, contains('would create CHANGELOG.md'));
      expect(written, contains('would create CHANGELOG.md'));
    });
  });
}
