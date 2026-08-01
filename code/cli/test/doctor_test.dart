import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/assets.dart';
import 'package:macss_cli/macss_cli.dart';
import 'package:macss_cli/modules/global/commands/doctor.dart';
import 'package:macss_cli/modules/global/commands/version.dart';

import 'support/memory_sink.dart';

Assets _makeAssets(Directory root, {List<String> presentTemplates = const []}) {
  final assets = Assets(root: root.path);
  for (final rel in presentTemplates) {
    final file = File(assets.path(rel));
    Directory(p.dirname(file.path)).createSync(recursive: true);
    file.writeAsStringSync('# template');
  }
  return assets;
}

/// Must mirror `templatePaths` in doctor.dart — that list is what `macss doctor`
/// asserts is installed, and this fixture is the "everything present" case.
const _allTemplates = [
  'templates/project-base/docs/adr/0001-record-architecture-decisions.md',
  'templates/project-base/docs/architecture.md',
  'templates/project-base/docs/roadmap.md',
  'artifacts/requisition.template.en.md',
  'artifacts/specification.template.en.md',
  'artifacts/issue.template.en.md',
  'skills/macss-specification/SKILL.md',
  'skills/macss-analyze/SKILL.md',
  'skills/macss-plan/SKILL.md',
  'skills/macss-execute/SKILL.md',
];

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('macss_doctor_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  DoctorCommand makeCmd(Assets assets) =>
      DoctorCommand(DoctorInput(), assets: assets);

  group('macss doctor', () {
    test('rejects an undeclared option (empty params contract)', () async {
      final stdout = MemorySink();
      final stderr = MemorySink();

      final code = await runMacss(
        const ['doctor', '--bogus'],
        stdout: stdout.sink,
        stderr: stderr.sink,
      );

      expect(code, 7); // ExitCode.validationFailed
      expect(await stderr.text(), contains('unknown option --bogus'));
    });

    test('all checks pass when assets and templates are present', () async {
      // Create the templates directory so directoryExists('templates') passes
      Directory(
        p.join(tempDir.path, 'assets', 'templates'),
      ).createSync(recursive: true);
      final assets = _makeAssets(tempDir, presentTemplates: _allTemplates);
      final output = await makeCmd(assets).execute();

      expect(output.exitCode, 0);
      expect(
        output.checks.every((c) => c.status == CheckStatus.ok),
        isTrue,
      );
    });

    test('version check always passes with current version', () async {
      final assets = _makeAssets(tempDir);
      final output = await makeCmd(assets).execute();

      final versionCheck = output.checks.first;
      expect(versionCheck.name, 'macss');
      expect(versionCheck.status, CheckStatus.ok);
      expect(versionCheck.detail, macssVersion);
    });

    test('assets check fails when templates dir is missing', () async {
      final assets = _makeAssets(tempDir);
      final output = await makeCmd(assets).execute();

      final assetsCheck = output.checks[1];
      expect(assetsCheck.name, 'assets');
      expect(assetsCheck.status, CheckStatus.error);
      expect(assetsCheck.remediation, isNotNull);
    });

    test('template checks fail individually when files are missing', () async {
      // Only templates dir present, no files
      Directory(
        p.join(tempDir.path, 'assets', 'templates'),
      ).createSync(recursive: true);
      final assets = _makeAssets(tempDir);
      final output = await makeCmd(assets).execute();

      final templateChecks = output.checks.skip(2);
      expect(
        templateChecks.every((c) => c.status == CheckStatus.error),
        isTrue,
      );
    });

    test('exitCode is 1 when any check fails', () async {
      final assets = _makeAssets(tempDir);
      final output = await makeCmd(assets).execute();
      expect(output.exitCode, 1);
    });

    test('toText contains ok symbol for passing checks', () async {
      Directory(
        p.join(tempDir.path, 'assets', 'templates'),
      ).createSync(recursive: true);
      final assets = _makeAssets(tempDir, presentTemplates: _allTemplates);
      final output = await makeCmd(assets).execute();
      expect(output.toText(), contains('✓'));
    });

    test('toText contains error symbol for failing checks', () async {
      final assets = _makeAssets(tempDir);
      final output = await makeCmd(assets).execute();
      expect(output.toText(), contains('✗'));
    });
  });
}
