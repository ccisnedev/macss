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

  RequisitionNewCommand newCommand({String? lang = 'es'}) {
    if (lang != null) declareLanguage(lang);
    return RequisitionNewCommand(
      RequisitionNewInput(slug: 'demo'),
      resolver: resolver,
      workingDirectory: tempDir.path,
      now: clock,
    );
  }

  Future<RequisitionNewOutput> open({String lang = 'es'}) async =>
      await applyCommand(newCommand(lang: lang));

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

      expect(out.did.map((s) => s.verb), contains('keep'));
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
        RequisitionNewInput(slug: ''),
        resolver: resolver,
        workingDirectory: tempDir.path,
      );
      expect(cmd.validate(), contains('<slug> is required'));
    });

    test('names every file it would open, and opens none', () async {
      final previews = await previewCommand(newCommand());

      expect(file('$folder/requisition.md').existsSync(), isFalse);
      expect(
        file('$folder/${RequisitionRecord.fileName}').existsSync(),
        isFalse,
      );

      final targets = previews.map((p) => p.target).join('\n');
      expect(targets, contains('requisition.md'));
      expect(targets, contains(RequisitionRecord.fileName));
      expect(previews.map((p) => p.verb), contains('activate'));
    });

    test('git-ignores the workspace before it writes into it', () async {
      // Not an ordering detail: a project must never have a committed .macss/,
      // and the plan is where that order is visible.
      final previews = await previewCommand(newCommand());

      expect(previews.first.target, '.gitignore');
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
      ProcessRunner? run,
      String? repo,
    }) => RequisitionPublishCommand(
      RequisitionPublishInput(repo: repo),
      workingDirectory: tempDir.path,
      runProcess: run ?? runner(),
    );

    /// Performs the steps, as `--apply --autoapprove` does. Most of these tests
    /// are about what reaches `gh`, not about the approval — and the approval
    /// is the SDK's, tested there.
    Future<RequisitionPublishOutput> publish({
      ProcessRunner? run,
      String? repo,
    }) async => await applyCommand(publishCommand(run: run, repo: repo));

    /// What it says it would do. Nothing reaches `gh`.
    Future<List<Preview>> plan({ProcessRunner? run, String? repo}) =>
        previewCommand(publishCommand(run: run, repo: repo));

    Future<void> fillForm() async {
      final form = file('$folder/requisition.md');
      form.writeAsStringSync(form
          .readAsStringSync()
          .replaceAll('<!-- Su respuesta aquí -->', 'Una respuesta real.'));
    }

    test('refuses to publish an unanswered form', () async {
      await open();

      await expectLater(
        publish(),
        throwsA(
          isA<CommandException>().having(
            (e) => e.message,
            'message',
            contains('REQ_NO_VALUE'),
          ),
        ),
      );
      expect(calls, isEmpty, reason: 'gh must not be reached');
    });

    test('says what it would do, and reaches no gh', () async {
      await open();
      await fillForm();

      final previews = await plan();

      expect(previews.first.verb, 'create');
      expect(previews.first.detail, contains('inferred by gh'));
      // The exact gh line is what actually reaches GitHub. A plan that hid it
      // would ask for approval of something the reader cannot see.
      expect(previews.first.detail, contains('gh issue create'));
      expect(calls, isEmpty);
    });

    // The value that motivates the whole arrangement: the issue's number does
    // not exist until the issue does, so the plan says so rather than omitting
    // it and reading as complete.
    test('declares the number it cannot know yet', () async {
      await open();
      await fillForm();

      final previews = await plan();

      expect(previews.first.pending, contains('issue'));
      expect(previews.last.verb, 'record');
      expect(previews.last.pending, contains('issue'));
    });

    test('creates the issue and records its number', () async {
      await open();
      await fillForm();

      final out = await publish(
        run: runner(stdout: 'https://github.com/o/r/issues/42'),
      );

      expect(out.issue, 42);
      expect(out.recorded, isTrue);
      expect(calls.single, containsAllInOrder(['gh', 'issue', 'create']));
      expect(calls.single, isNot(contains('--repo')));

      final dir = p.dirname(file('$folder/x').path);
      final record = RequisitionRecord.read(dir)!;
      expect(record.issue, 42);
      expect(record.state, RequisitionState.published,
          reason: 'the number and the state it justifies are written together');
    });

    // The number is read from the step that produced it, not asked of GitHub a
    // second time — a second question could answer differently.
    test('the recording step reads the number from the publishing one',
        () async {
      await open();
      await fillForm();

      final execution = await runCommand(
        publishCommand(run: runner(stdout: 'https://github.com/o/r/issues/42')),
      );

      expect(execution.isFaithful, isTrue);
      expect(execution.outcomes.last.values['issue'], 42);
      expect(calls, hasLength(1), reason: 'gh is asked once, not twice');
    });

    test('a second publish edits the issue it already created', () async {
      await open();
      await fillForm();
      await publish(run: runner(stdout: 'https://github.com/o/r/issues/42'));
      calls.clear();

      final out = await publish();

      expect(out.updated, isTrue);
      expect(calls.single, containsAllInOrder(['gh', 'issue', 'edit', '42']));
    });

    test('an issue that already has a number has nothing to record', () async {
      await open();
      await fillForm();
      await publish(run: runner(stdout: 'https://github.com/o/r/issues/42'));

      final previews = await plan();

      expect(previews, hasLength(1));
      expect(previews.single.verb, 'update');
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

      await publish(run: runner(stdout: 'https://github.com/o/r/issues/42'));

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

      final out = await publish();

      expect(out.updated, isTrue);
      expect(calls.single, containsAllInOrder(['issue', 'edit', '42']));
      expect(calls.single, containsAllInOrder(['--add-label', 'bug']));
      expect(calls.single, containsAllInOrder(['--add-label', 'app']));
      expect(calls.single, isNot(contains('--label')),
          reason: 'gh issue edit rejects --label');
    });

    test('the body grows when the specification appears', () async {
      await open();
      await fillForm();
      final before = (await plan()).first.detail!;

      file('$folder/specification.md').writeAsStringSync('# Contrato\n\nTexto.');
      final after = (await plan()).first.detail!;

      expect(before, contains('requisition.md'));
      expect(before, isNot(contains('specification.md')));
      expect(after, contains('requisition.md + specification.md'));
    });

    test('--repo overrides what gh would infer', () async {
      await open();
      await fillForm();

      await publish(repo: 'owner/other');

      expect(calls.single, containsAllInOrder(['--repo', 'owner/other']));
    });

    test('a body over the GitHub limit fails before reaching gh', () async {
      await open();
      await fillForm();
      file('$folder/specification.md')
          .writeAsStringSync('x' * (githubBodyLimit + 1));

      await expectLater(
        publish(),
        throwsA(
          isA<CommandException>().having(
            (e) => e.message,
            'message',
            contains('$githubBodyLimit'),
          ),
        ),
      );
      expect(calls, isEmpty, reason: 'no point asking gh to reject it');
    });

    test('a gh failure stops the run and is reported, not swallowed', () async {
      await open();
      await fillForm();

      final execution = await runCommand(
        publishCommand(run: runner(exitCode: 1)),
      );

      // The step threw, so the run is incomplete — and the recording step that
      // follows it never runs, which is the point: there is no number to record.
      expect(execution.isComplete, isFalse);
      expect(execution.failure!.message, contains('failed'));
      expect(execution.outcomes, isEmpty);
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