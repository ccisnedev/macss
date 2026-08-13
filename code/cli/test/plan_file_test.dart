/// Where MACSS files the plans that `--plan` produces.
///
/// What used to live beside this — `ChangeFlags`, `ConsoleApprover`,
/// `ChangeGate` — moved into `modular_cli_sdk` 0.4.0, which declares and applies
/// the convention for every command and tests it there. Keeping a copy of those
/// tests here would have tested the SDK from a second place, which is where two
/// descriptions of one rule start to disagree.
///
/// What is left is the one decision the SDK deliberately does not take: whether
/// a plan is kept on disk, and where.
library;

import 'dart:io';

import 'package:macss_cli/src/plan_file.dart';
import 'package:macss_cli/src/project_config.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('macss_plan_file_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  DateTime clock() => DateTime(2026, 8, 4, 9, 30, 15);

  PlanDocument planOf(String route, List<Preview> previews) =>
      PlanDocument(route: route, previews: previews);

  group('the plan document', () {
    test('reads on its own, away from the terminal', () {
      final path = PlanFile.write(
        workingDirectory: tempDir.path,
        plan: planOf('project adopt', [
          Preview(verb: 'create', target: 'CHANGELOG.md'),
        ]),
        now: clock(),
      );

      final plan = File(path).readAsStringSync();
      expect(plan, contains('macss project adopt'));
      expect(plan, contains('create'));
      expect(plan, contains('CHANGELOG.md'));
      expect(plan, contains('Nothing was changed'));
      expect(plan, contains('--apply'));
      expect(plan, contains('2026-08-04'));
    });

    test('says what a step could not know yet', () {
      final path = PlanFile.write(
        workingDirectory: tempDir.path,
        plan: planOf('requisition publish', [
          Preview(
            verb: 'create',
            target: 'the issue',
            pending: const ['issue'],
          ),
        ]),
        now: clock(),
      );

      expect(
        File(path).readAsStringSync(),
        contains('issue: known once this runs'),
      );
    });

    test('lands under the MACSS workspace, which is git-ignored', () {
      final path = PlanFile.write(
        workingDirectory: tempDir.path,
        plan: planOf('requisition publish', [
          Preview(verb: 'create', target: 'x'),
        ]),
        now: clock(),
      );

      expect(path, contains('.macss'));
      expect(path, contains('plans'));
      expect(path, endsWith('requisition-publish.md'));
    });

    test('the stamp keeps successive plans apart, so two runs compare', () {
      final first = PlanFile.write(
        workingDirectory: tempDir.path,
        plan: planOf('project adopt', [Preview(verb: 'create', target: 'a')]),
        now: DateTime(2026, 8, 4, 9, 30, 15),
      );
      final second = PlanFile.write(
        workingDirectory: tempDir.path,
        plan: planOf('project adopt', [Preview(verb: 'create', target: 'b')]),
        now: DateTime(2026, 8, 4, 9, 30, 16),
      );

      expect(second, isNot(first));
      expect(File(first).readAsStringSync(), contains('a'));
      expect(File(second).readAsStringSync(), contains('b'));
    });
  });

  group('the sink', () {
    // Five commands are built to run where no project exists —
    // `requisition export-template`, `skill deploy`, `skill clean`, `upgrade`
    // and `uninstall`. Filing a plan there would answer a request for a blank
    // form by creating a workspace nobody asked for.
    test('files nothing outside a MACSS project', () {
      final sink = macssPlanSink(
        now: clock,
        workingDirectory: tempDir.path,
      );

      final filed = sink(
        planOf('requisition export-template', [
          Preview(verb: 'create', target: 'requisition.md'),
        ]),
      );

      expect(filed, isNull);
      expect(Directory(p.join(tempDir.path, '.macss')).existsSync(), isFalse);
    });

    test('files inside one', () {
      writeProjectConfig(tempDir.path, language: 'es');
      final sink = macssPlanSink(
        now: clock,
        workingDirectory: tempDir.path,
      );

      final filed = sink(
        planOf('requisition new', [
          Preview(verb: 'create', target: 'requisition.md'),
        ]),
      );

      expect(filed, isNotNull);
      expect(File(filed!).existsSync(), isTrue);
    });

    // The marker is the configuration a human wrote, not the directory some
    // command happened to create. This rule exists to stop `.macss/` appearing
    // by accident, so it cannot take `.macss/` as proof of anything.
    test('a bare .macss/ is not a project', () {
      Directory(p.join(tempDir.path, '.macss')).createSync(recursive: true);

      expect(isMacssProject(tempDir.path), isFalse);
    });
  });
}
