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
import 'package:macss_cli/src/plan_apply.dart';
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

  RequisitionNewCommand newCommand({
    String lang = 'es',
    ChangeFlags flags = const ChangeFlags(apply: true, autoapprove: true),
    Approver? approver,
  }) =>
      RequisitionNewCommand(
        RequisitionNewInput(slug: 'demo', lang: lang, flags: flags),
        resolver: resolver,
        workingDirectory: tempDir.path,
        now: clock,
        approver: approver,
      );

  Future<RequisitionNewOutput> open({String lang = 'es'}) =>
      newCommand(lang: lang).execute();

  File file(String relative) =>
      File(p.join(tempDir.path, p.joinAll(relative.split('/'))));

  group('macss requisition new', () {
    test('writes the form, the issue metadata and the active pointer',
        () async {
      await open();

      expect(file('$folder/requisition.md').existsSync(), isTrue);
      expect(file('$folder/issue.yaml').existsSync(), isTrue);
      expect(file('.macss/state.yaml').existsSync(), isTrue);
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
        RequisitionNewInput(
          slug: '',
          lang: 'en',
          flags: const ChangeFlags(apply: true, autoapprove: true),
        ),
        resolver: resolver,
        workingDirectory: tempDir.path,
      );
      expect(cmd.validate(), contains('<slug> is required'));
    });

    test('a bare invocation opens nothing', () async {
      final cmd = newCommand(flags: const ChangeFlags());

      expect(cmd.validate(), contains('Choose --plan or --apply'));
      expect(Directory(p.join(tempDir.path, 'docs')).existsSync(), isFalse);
    });

    test('--plan names every file it would open, and opens none', () async {
      final out = await newCommand(flags: const ChangeFlags(plan: true))
          .execute();

      expect(file('$folder/requisition.md').existsSync(), isFalse);
      expect(file('$folder/${IssueMetadata.fileName}').existsSync(), isFalse);
      expect(out.planPath, isNotNull);

      final plan = File(out.planPath!).readAsStringSync();
      expect(plan, contains('requisition.md'));
      expect(plan, contains(IssueMetadata.fileName));
      expect(plan, contains('active requisition'));
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
    Future<ExportTemplateOutput> export({
      String lang = 'es',
      ChangeFlags flags = const ChangeFlags(apply: true, autoapprove: true),
    }) =>
        ExportTemplateCommand(
          ExportTemplateInput(
            resolvedPath: tempDir.path,
            lang: lang,
            flags: flags,
          ),
          resolver: resolver,
          artifact: 'requisition',
          now: clock,
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

    test('--plan names the form it would write, and writes none', () async {
      final out = await export(flags: const ChangeFlags(plan: true));

      expect(file('requisition.md').existsSync(), isFalse);
      expect(out.planPath, isNotNull);
      expect(File(out.planPath!).readAsStringSync(), contains('requisition'));
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

    RequisitionPublishCommand publishCommand({
      bool plan = false,
      bool apply = false,
      bool autoapprove = true,
      ProcessRunner? run,
      String? repo,
      Approver? approver,
    }) =>
        RequisitionPublishCommand(
          RequisitionPublishInput(
            flags: ChangeFlags(
                plan: plan, apply: apply, autoapprove: autoapprove),
            repo: repo,
          ),
          workingDirectory: tempDir.path,
          runProcess: run ?? runner(),
          approver: approver,
          now: () => DateTime(2026, 8, 2, 9, 30, 15),
        );

    /// Defaults to `--apply --autoapprove`: most of these tests are about what
    /// reaches `gh`, not about the approval, and an unattended default keeps
    /// them from turning into approval tests by accident.
    Future<RequisitionPublishOutput> publish({
      bool plan = false,
      bool apply = false,
      bool autoapprove = true,
      ProcessRunner? run,
      String? repo,
      Approver? approver,
    }) =>
        publishCommand(
          plan: plan,
          apply: apply,
          autoapprove: autoapprove,
          run: run,
          repo: repo,
          approver: approver,
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

    test('--plan reaches no gh and writes the plan file', () async {
      await open();
      await fillForm();

      final out = await publish(plan: true);

      expect(out.message, contains('would create'));
      expect(out.message, contains('inferred by gh'));
      expect(calls, isEmpty);

      expect(out.planPath, isNotNull);
      final written = File(out.planPath!).readAsStringSync();
      // The exact gh line is what actually reaches GitHub. A plan that hid it
      // would ask for approval of something the reader cannot see.
      expect(written, contains('gh issue create'));
      expect(written, contains('macss requisition publish'));
    });

    test('a bare publish is a usage error and reaches no gh', () async {
      await open();
      await fillForm();

      final error = publishCommand(autoapprove: false).validate();

      expect(error, contains('Choose --plan or --apply'));
      expect(calls, isEmpty);
    });

    test('--apply asks before anything reaches gh', () async {
      await open();
      await fillForm();
      var shown = '';

      await publish(
        apply: true,
        autoapprove: false,
        approver: (plan) async {
          shown = plan;
          return true;
        },
      );

      expect(shown, contains('gh issue create'));
      expect(calls.single, containsAllInOrder(['gh', 'issue', 'create']));
    });

    test('a refusal reaches no gh and fails', () async {
      await open();
      await fillForm();

      final out = await publish(
        apply: true,
        autoapprove: false,
        approver: (_) async => false,
      );

      expect(out.ok, isFalse);
      expect(calls, isEmpty, reason: 'nothing may reach GitHub after a refusal');
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

    // `gh issue create` takes --label; `gh issue edit` rejects it and takes
    // --add-label. Sending --label to both is what shipped, so every update of
    // a requisition that declared any label failed with `unknown flag:
    // --label` — and only after the create path had already succeeded once.
    test('creating an issue labels it with --label', () async {
      await open();
      await fillForm();
      const IssueMetadata(title: 'Un título', labels: ['bug'], lang: 'es')
          .write(p.dirname(file('$folder/x').path));

      await publish(
          apply: true, run: runner(stdout: 'https://github.com/o/r/issues/42'));

      expect(calls.single, containsAllInOrder(['issue', 'create']));
      expect(calls.single, containsAllInOrder(['--label', 'bug']));
    });

    test('editing an issue labels it with --add-label', () async {
      await open();
      await fillForm();
      const IssueMetadata(
        title: 'Un título',
        labels: ['bug', 'app'],
        lang: 'es',
        issue: 42,
      ).write(p.dirname(file('$folder/x').path));

      final out = await publish(apply: true);

      expect(out.ok, isTrue, reason: out.message);
      expect(calls.single, containsAllInOrder(['issue', 'edit', '42']));
      expect(calls.single, containsAllInOrder(['--add-label', 'bug']));
      expect(calls.single, containsAllInOrder(['--add-label', 'app']));
      expect(calls.single, isNot(contains('--label')),
          reason: 'gh issue edit rejects --label');
    });

    test('the body grows when the specification appears', () async {
      await open();
      await fillForm();
      final before = await publish(plan: true);

      file('$folder/specification.md').writeAsStringSync('# Contrato\n\nTexto.');
      final after = await publish(plan: true);

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