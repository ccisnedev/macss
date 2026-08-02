import 'dart:io';

import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/assets.dart';
import 'package:macss_cli/modules/requisition/commands/check.dart';
import 'package:macss_cli/modules/requisition/commands/export_template.dart';
import 'package:macss_cli/modules/requisition/commands/new.dart';
import 'package:macss_cli/modules/requisition/issue_metadata.dart';
import 'package:macss_cli/modules/requisition/commands/publish.dart';
import 'package:macss_cli/modules/requisition/publisher.dart';
import 'package:macss_cli/modules/requisition/requisition_builder.dart';
import 'package:macss_cli/templates/template_resolver.dart';

import 'support/memory_sink.dart';

void main() {
  late Directory tempDir;
  late Assets assets;
  late TemplateResolver resolver;

  /// Fixed so the dated folder is deterministic.
  DateTime clock() => DateTime(2026, 8, 2);
  const folder = 'docs/requisitions/20260802-demo';

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('macss_requisition_test_');
    assets = Assets(root: Directory.current.path);
    resolver = TemplateResolver(assets);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<RequisitionNewOutput> open({String lang = 'es'}) =>
      RequisitionNewCommand(
        RequisitionNewInput(slug: 'demo', lang: lang),
        resolver: resolver,
        workingDirectory: tempDir.path,
        now: clock,
      ).execute();

  File file(String relative) =>
      File(p.join(tempDir.path, p.joinAll(relative.split('/'))));

  group('macss requisition new', () {
    test('writes the form, the issue metadata and the active pointer',
        () async {
      await open();

      expect(file('$folder/requisition.md').existsSync(), isTrue);
      expect(file('$folder/issue.yaml').existsSync(), isTrue);
      expect(file('.macss/specification.yaml').existsSync(), isTrue);
    });

    test('does not create the specification', () async {
      // It belongs to a later stage, with a different author.
      await open();
      expect(file('$folder/specification.md').existsSync(), isFalse);
    });

    test('keeps the workspace out of version control', () async {
      await open();

      final gitignore = file('.gitignore').readAsStringSync();
      expect(gitignore, contains('.macss/'));
      expect(gitignore, contains('docs/requisitions/'));
    });

    test('is idempotent — a second run keeps what is there', () async {
      await open();
      file('$folder/requisition.md').writeAsStringSync('EDITED BY THE PO');

      final out = await open();

      expect(out.message, contains('kept'));
      expect(file('$folder/requisition.md').readAsStringSync(),
          'EDITED BY THE PO');
    });

    test('the form is in the language asked for', () async {
      await open(lang: 'es');
      expect(file('$folder/requisition.md').readAsStringSync(),
          contains('Situación actual'));
    });

    test('validate rejects an empty slug', () {
      final cmd = RequisitionNewCommand(
        RequisitionNewInput(slug: '', lang: 'en'),
        resolver: resolver,
        workingDirectory: tempDir.path,
      );
      expect(cmd.validate(), contains('<slug> is required'));
    });
  });

  group('issue.yaml', () {
    test('starts unpublished, which is how the DoR knows', () async {
      await open();

      final meta = IssueMetadata.read(p.dirname(file('$folder/x').path))!;
      expect(meta.isPublished, isFalse);
      expect(meta.issue, isNull);
      expect(meta.lang, 'es');
    });

    test('carries no repo — gh infers it from the directory', () async {
      await open();
      expect(file('$folder/issue.yaml').readAsStringSync(),
          isNot(contains('repo:')));
    });

    test('round-trips the fields a person edits', () {
      const meta = IssueMetadata(
        title: 'Consulta del estado de un pedido',
        labels: ['enhancement', 'app'],
        lang: 'es',
      );
      final dir = tempDir.path;
      meta.write(dir);

      final read = IssueMetadata.read(dir)!;
      expect(read.title, meta.title);
      expect(read.labels, meta.labels);
      expect(read.withIssue(42).issue, 42);
    });
  });

  group('macss requisition check', () {
    Future<RequisitionCheckOutput> check() => RequisitionCheckCommand(
          RequisitionCheckInput(),
          workingDirectory: tempDir.path,
        ).execute();

    test('a blank form fails, naming what is unanswered', () async {
      await open();

      final out = await check();

      expect(out.passed, isFalse);
      expect(out.exitCode, ExitCode.validationFailed);
      expect(out.message, contains('REQ_NO_VALUE'));
    });

    test('a filled form passes', () async {
      await open();
      final form = file('$folder/requisition.md');
      form.writeAsStringSync(form
          .readAsStringSync()
          .replaceAll('<!-- Su respuesta aquí -->', 'Una respuesta real.'));

      final out = await check();

      expect(out.passed, isTrue, reason: out.message);
      expect(out.exitCode, ExitCode.ok);
    });

    test('validate explains when there is no requisition at all', () {
      final cmd = RequisitionCheckCommand(
        RequisitionCheckInput(),
        workingDirectory: tempDir.path,
      );
      expect(cmd.validate(), contains('requisition new'));
    });
  });

  group('macss requisition export-template', () {
    Future<ExportTemplateOutput> export({String lang = 'es'}) =>
        ExportTemplateCommand(
          ExportTemplateInput(resolvedPath: tempDir.path, lang: lang),
          resolver: resolver,
          artifact: 'requisition',
        ).execute();

    test('writes the blank form where asked', () async {
      final out = await export();

      expect(File(out.path).existsSync(), isTrue);
      expect(p.basename(out.path), 'requisition.md');
      expect(File(out.path).readAsStringSync(), contains('Necesidad y valor'));
    });

    test('does not touch the requisitions workspace', () async {
      // Scaffolding a throwaway requisition to get a blank form would litter
      // docs/requisitions/ and move the active pointer.
      await export();

      expect(file('docs').existsSync(), isFalse);
      expect(file('.macss').existsSync(), isFalse);
    });

    test('refuses to overwrite an existing file', () async {
      await export();
      File(p.join(tempDir.path, 'requisition.md')).writeAsStringSync('MINE');

      final out = await export();

      expect(out.exitCode, ExitCode.conflict);
      expect(File(p.join(tempDir.path, 'requisition.md')).readAsStringSync(),
          'MINE');
    });
  });

  // Contract style: through a real ModularCli, so parse-time enforcement is
  // exercised end to end.
  group('macss requisition publish', () {
    late List<List<String>> calls;

    ProcessRunner runner({int exitCode = 0, String stdout = ''}) =>
        (executable, arguments) async {
          calls.add([executable, ...arguments]);
          return ProcessResult(0, exitCode, stdout, '');
        };

    setUp(() => calls = []);

    Future<RequisitionPublishOutput> publish({
      bool apply = false,
      ProcessRunner? run,
      String? repo,
    }) =>
        RequisitionPublishCommand(
          RequisitionPublishInput(apply: apply, repo: repo),
          workingDirectory: tempDir.path,
          runProcess: run ?? runner(),
        ).execute();

    Future<void> fillForm() async {
      final form = file('$folder/requisition.md');
      form.writeAsStringSync(form
          .readAsStringSync()
          .replaceAll('<!-- Su respuesta aquí -->', 'Una respuesta real.'));
    }

    test('refuses to publish an unanswered form', () async {
      await open();

      final out = await publish(apply: true);

      expect(out.ok, isFalse);
      expect(out.message, contains('REQ_NO_VALUE'));
      expect(calls, isEmpty, reason: 'gh must not be reached');
    });

    test('previews by default and runs nothing', () async {
      await open();
      await fillForm();

      final out = await publish();

      expect(out.message, contains('would create'));
      expect(out.message, contains('inferred by gh'));
      expect(calls, isEmpty);
    });

    test('--apply creates the issue and records its number', () async {
      await open();
      await fillForm();

      final out = await publish(
        apply: true,
        run: runner(stdout: 'https://github.com/o/r/issues/42'),
      );

      expect(out.ok, isTrue, reason: out.message);
      expect(out.issue, 42);
      expect(calls.single, containsAllInOrder(['gh', 'issue', 'create']));
      expect(calls.single, isNot(contains('--repo')));

      final dir = p.dirname(file('$folder/x').path);
      expect(IssueMetadata.read(dir)!.issue, 42);
    });

    test('a second publish edits the issue it already created', () async {
      await open();
      await fillForm();
      await publish(
          apply: true, run: runner(stdout: 'https://github.com/o/r/issues/42'));
      calls.clear();

      final out = await publish(apply: true);

      expect(out.message, contains('updated'));
      expect(calls.single, containsAllInOrder(['gh', 'issue', 'edit', '42']));
    });

    test('the body grows when the specification appears', () async {
      await open();
      await fillForm();
      final before = await publish();

      file('$folder/specification.md').writeAsStringSync('# Contrato\n\nTexto.');
      final after = await publish();

      expect(before.message, contains('requisition.md'));
      expect(before.message, isNot(contains('specification.md')));
      expect(after.message, contains('requisition.md + specification.md'));
    });

    test('--repo overrides what gh would infer', () async {
      await open();
      await fillForm();

      await publish(apply: true, repo: 'owner/other');

      expect(calls.single, containsAllInOrder(['--repo', 'owner/other']));
    });

    test('a body over the GitHub limit fails before reaching gh', () async {
      await open();
      await fillForm();
      file('$folder/specification.md')
          .writeAsStringSync('x' * (githubBodyLimit + 1));

      final out = await publish(apply: true);

      expect(out.ok, isFalse);
      expect(out.message, contains('$githubBodyLimit'));
      expect(calls, isEmpty, reason: 'no point asking gh to reject it');
    });

    test('a gh failure is reported, not swallowed', () async {
      await open();
      await fillForm();

      final out = await publish(apply: true, run: runner(exitCode: 1));

      expect(out.ok, isFalse);
      expect(out.message, contains('failed'));
    });
  });

  group('macss requisition contract', () {
    ModularCli makeCli() => ModularCli()
      ..module('requisition', (m) => buildRequisitionModule(m, assets: assets));

    test('rejects an undeclared option', () async {
      final stderr = MemorySink();
      final code = await makeCli().run(
        ['requisition', 'check', '--bogus'],
        stdout: MemorySink().sink,
        stderr: stderr.sink,
      );

      expect(code, ExitCode.validationFailed);
      expect(await stderr.text(), contains('unknown option --bogus'));
    });

    test('rejects a language outside the allowed set', () async {
      final code = await makeCli().run(
        ['requisition', 'export-template', '--lang=klingon'],
        stdout: MemorySink().sink,
        stderr: MemorySink().sink,
      );

      expect(code, ExitCode.validationFailed);
    });
  });
}