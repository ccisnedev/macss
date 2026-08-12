import 'dart:io';

import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:modular_cli_sdk/testing.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/assets.dart';
import 'package:macss_cli/modules/requisition/commands/check.dart';
import 'package:macss_cli/modules/requisition/commands/export_template.dart';
import 'package:macss_cli/modules/requisition/commands/new.dart';
import 'package:macss_cli/modules/requisition/requisition_record.dart';
import 'package:macss_cli/modules/requisition/commands/publish.dart';
import 'package:macss_cli/modules/requisition/publisher.dart';
import 'package:macss_cli/modules/requisition/requisition_builder.dart';
import 'package:macss_cli/src/project_config.dart';
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

  /// The project says which language it speaks, once. Commands derive it from
  /// here — there is no `--lang` to pass them.
  void declareLanguage(String lang) =>
      writeProjectConfig(tempDir.path, language: lang);

  RequisitionNewCommand newCommand({
    String? lang = 'es',
    ChangeFlags flags = const ChangeFlags(apply: true, autoapprove: true),
    Approver? approver,
  }) {
    if (lang != null) declareLanguage(lang);
    return RequisitionNewCommand(
      RequisitionNewInput(slug: 'demo', flags: flags),
      resolver: resolver,
      workingDirectory: tempDir.path,
      now: clock,
      approver: approver,
    );
  }

  Future<RequisitionNewOutput> open({String lang = 'es'}) =>
      newCommand(lang: lang).execute();

  File file(String relative) =>
      File(p.join(tempDir.path, p.joinAll(relative.split('/'))));

  group('macss requisition new', () {
    test('writes the form, the lifecycle record and the active pointer',
        () async {
      await open();

      expect(file('$folder/requisition.md').existsSync(), isTrue);
      expect(file('$folder/state.yaml').existsSync(), isTrue);
      expect(file('.macss/active_requisition.yaml').existsSync(), isTrue);
      expect(file('$folder/issue.yaml').existsSync(), isFalse,
          reason: 'issue.yaml is replaced, not written alongside');
    });

    test('the requisition starts at the first state of the ladder', () async {
      await open();

      final record =
          RequisitionRecord.read(p.dirname(file('$folder/x').path))!;
      expect(record.state, RequisitionState.opened);
      expect(record.issue, isNull);
    });

    test('does not create the specification', () async {
      // It belongs to a later stage, with a different author.
      await open();
      expect(file('$folder/specification.md').existsSync(), isFalse);
    });

    test('keeps the authoring workspace out of version control', () async {
      await open();

      expect(file('.gitignore').readAsStringSync(),
          contains('docs/requisitions/'));
    });

    // `.macss/` is deliberately absent from the root. It carries its own
    // .gitignore, and a rule at this level would make that one dead letter —
    // git does not descend into an excluded directory, so nothing inside could
    // be re-included and the project configuration could never be versioned.
    test('leaves the ignoring of .macss/ to .macss/ itself', () async {
      await open();

      expect(file('.gitignore').readAsStringSync(), isNot(contains('.macss/')));
      expect(file('.macss/.gitignore').existsSync(), isTrue);
    });

    // A copy of the declaration is a second answer waiting to disagree with the
    // first. `.macss/config.yaml` says it once; nothing downstream repeats it.
    test('copies the language into neither state.yaml nor the pointer',
        () async {
      await open(lang: 'es');

      expect(file('$folder/state.yaml').readAsStringSync(),
          isNot(contains('lang')));
      expect(file('.macss/active_requisition.yaml').readAsStringSync(),
          isNot(contains('lang')));
    });

    test('is idempotent — a second run keeps what is there', () async {
      await open();
      file('$folder/requisition.md').writeAsStringSync('EDITED BY THE PO');

      final out = await open();

      expect(out.message, contains('kept'));
      expect(file('$folder/requisition.md').readAsStringSync(),
          'EDITED BY THE PO');
    });

    test('the form is in the language the project declared', () async {
      await open(lang: 'es');
      expect(file('$folder/requisition.md').readAsStringSync(),
          contains('Situación actual'));
    });

    // The document travels: it is sent as PDF or DOCX to a Product Owner who
    // has no repository to consult. So it says what language it is in, on its
    // own face, rather than only in the configuration that produced it.
    test('the form declares its own language, for when it travels alone',
        () async {
      await open(lang: 'es');
      expect(file('$folder/requisition.md').readAsStringSync(),
          contains('macss:lang=es'));
    });

    // No default: a project that never said which language it speaks is
    // stopped and told how to say it, not assumed to be English.
    test('refuses to open a requisition where no language is declared', () {
      final cmd = newCommand(lang: null);

      final failure = cmd.validate();
      expect(failure, isNotNull);
      expect(failure, contains('macss project adopt --lang <en|es> --apply'));
      expect(file('docs').existsSync(), isFalse);
    });

    test('validate rejects an empty slug', () {
      declareLanguage('en');
      final cmd = RequisitionNewCommand(
        RequisitionNewInput(
          slug: '',
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
      expect(file('$folder/${RequisitionRecord.fileName}').existsSync(), isFalse);
      expect(out.planPath, isNotNull);

      final plan = File(out.planPath!).readAsStringSync();
      expect(plan, contains('requisition.md'));
      expect(plan, contains(RequisitionRecord.fileName));
      expect(plan, contains('active requisition'));
    });
  });

  group('state.yaml', () {
    test('carries no repo — gh infers it from the directory', () async {
      await open();
      expect(file('$folder/state.yaml').readAsStringSync(),
          isNot(contains('repo:')));
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
    ExportTemplateCommand exporter({String lang = 'es'}) =>
        ExportTemplateCommand(
          ExportTemplateInput(resolvedPath: tempDir.path, lang: lang),
          resolver: resolver,
          artifact: 'requisition',
        );

    Future<ExportTemplateOutput> export({String lang = 'es'}) async =>
        await applyCommand(exporter(lang: lang));

    test('writes the blank form where asked, project or not', () async {
      // tempDir is not a MACSS project: no `.macss/`, nothing to derive the
      // language from. Declaring it is what makes the command answerable here.
      expect(file('.macss').existsSync(), isFalse);

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

    test('names the form it would write, and writes none', () async {
      final previews = await previewCommand(exporter());

      expect(previews.single.verb, 'create');
      expect(previews.single.target, endsWith('requisition.md'));
      expect(file('requisition.md').existsSync(), isFalse);
    });

    // The defect the plan sink's rule corrects. This command exists to be run
    // where no project does, so filing a plan would answer a request for a
    // blank form by creating a workspace nobody asked for.
    test('asking what it would do creates no workspace either', () async {
      await previewCommand(exporter());

      expect(file('.macss').existsSync(), isFalse);
    });

    test('carries the template it resolved, not a promise to resolve it later',
        () async {
      // The contents are settled when the step is built. Deriving them again
      // inside perform is how a preview comes to describe a different change
      // from the one that happens.
      final previews = await previewCommand(exporter());

      expect(previews.single.detail, isNotNull);
    });

    test('refuses to overwrite an existing file', () async {
      await export();
      File(p.join(tempDir.path, 'requisition.md')).writeAsStringSync('MINE');

      // Thrown rather than reported, so it stays a conflict and not a
      // validation failure — and so it happens before anything is planned.
      await expectLater(
        previewCommand(exporter()),
        throwsA(
          isA<CommandException>().having(
            (e) => e.exitCode,
            'exitCode',
            ExitCode.conflict,
          ),
        ),
      );
      expect(
        File(p.join(tempDir.path, 'requisition.md')).readAsStringSync(),
        'MINE',
      );
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
      final record = RequisitionRecord.read(dir)!;
      expect(record.issue, 42);
      expect(record.state, RequisitionState.published,
          reason: 'the number and the state it justifies are written together');
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
      const RequisitionRecord(
        title: 'Un título',
        labels: ['bug'],
        state: RequisitionState.opened,
      ).write(p.dirname(file('$folder/x').path));

      await publish(
          apply: true, run: runner(stdout: 'https://github.com/o/r/issues/42'));

      expect(calls.single, containsAllInOrder(['issue', 'create']));
      expect(calls.single, containsAllInOrder(['--label', 'bug']));
    });

    test('editing an issue labels it with --add-label', () async {
      await open();
      await fillForm();
      const RequisitionRecord(
        title: 'Un título',
        labels: ['bug', 'app'],
        state: RequisitionState.published,
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

    // The one command that keeps --lang is the one that requires it: it writes
    // where no MACSS project need exist, so there is nothing to derive from.
    // The rule is not weakened here — this is the reason it has an exception.
    test('refuses to guess the language when none is declared', () async {
      final stderr = MemorySink();

      final code = await makeCli().run(
        ['requisition', 'export-template', '--path=${tempDir.path}',
          '--apply', '--autoapprove'],
        stdout: MemorySink().sink,
        stderr: stderr.sink,
      );

      final error = await stderr.text();
      expect(code, ExitCode.validationFailed);
      expect(error, contains('--lang'));
      expect(error, contains('nothing to derive it from'));
      expect(file('requisition.md').existsSync(), isFalse);
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