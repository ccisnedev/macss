import 'dart:io';

import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;
import 'package:modular_cli_sdk/testing.dart';
import 'package:test/test.dart';

import 'package:macss_cli/assets.dart';
import 'package:macss_cli/modules/project/canon.dart';
import 'package:macss_cli/modules/project/commands/adopt.dart';
import 'package:macss_cli/modules/project/commands/check.dart';
import 'package:macss_cli/modules/project/commands/create.dart';
import 'package:macss_cli/modules/project/project_builder.dart';
import 'package:macss_cli/src/project_config.dart';

import 'support/memory_sink.dart';

void main() {
  late Directory tempRoot;
  late Assets assets;
  late String dest;

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('macss_canon_test_');
    dest = p.join(tempRoot.path, 'proj');

    // A fixture that mirrors the shipped asset tree: one file per canon entry,
    // so `create` and `adopt` can stamp every one of them.
    final assetsDir = Directory(p.join(tempRoot.path, '_assets'));
    for (final file in canonFiles) {
      final f = File(p.join(assetsDir.path, 'assets', p.joinAll(file.template.split('/'))));
      f.createSync(recursive: true);
      f.writeAsStringSync('# ${file.path}\n');
    }
    assets = Assets(root: assetsDir.path);
  });

  tearDown(() {
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  Future<void> scaffold() async {
    await applyCommand(
      CreateCommand(
        CreateInput(
          resolvedPath: dest,
          workingDirectory: tempRoot.path,
          lang: 'en',
        ),
        assets: assets,
      ),
    );
  }

  Future<ProjectCheckOutput> check() =>
      ProjectCheckCommand(ProjectCheckInput(resolvedPath: dest)).execute();

  ProjectAdoptCommand adoptCommand({String? lang = 'en'}) =>
      ProjectAdoptCommand(
        ProjectAdoptInput(resolvedPath: dest, lang: lang),
        assets: assets,
      );

  Future<ProjectAdoptOutput> adopt({String? lang = 'en'}) async =>
      await applyCommand(adoptCommand(lang: lang));

  /// What it says it would do. Nothing is adopted.
  Future<List<Preview>> plan({String? lang = 'en'}) =>
      previewCommand(adoptCommand(lang: lang));

  void mkdirs(String relative) =>
      Directory(p.join(dest, p.joinAll(relative.split('/'))))
          .createSync(recursive: true);

  group('the canon is one definition', () {
    // The defect this module exists to prevent: the book required a root
    // CHANGELOG.md that `create` never stamped, and nothing detected it.
    test('a freshly created project conforms — exit 0', () async {
      await scaffold();

      final out = await check();

      expect(out.missing, 0, reason: out.toText());
      expect(out.deviations, 0, reason: out.toText());
      expect(out.exitCode, ExitCode.ok);
    });

    test('CHANGELOG.md is part of the canon and is stamped', () async {
      await scaffold();
      expect(File(p.join(dest, 'CHANGELOG.md')).existsSync(), isTrue);
      expect(canonFiles.map((f) => f.path), contains('CHANGELOG.md'));
    });
  });

  group('macss project check', () {
    test('reports every canonical file missing from an empty directory',
        () async {
      Directory(dest).createSync(recursive: true);

      final out = await check();

      expect(out.missing, canonFiles.length);
      expect(out.exitCode, 1);
      // With `--lang`: #24 made it required, which silently invalidated the
      // very message this method started from. This assertion passed
      // throughout, because it pinned the prefix rather than the invocation.
      expect(out.toText(),
          contains('macss project adopt --lang <en|es> --plan'));
    });

    test('an api module with no db module is a warning, not an error',
        () async {
      await scaffold();
      mkdirs('code/api/modules/sales');

      final out = await check();

      expect(out.missing, 0);
      expect(out.deviations, 1);
      // A deviation never fails the command: it needs judgement, not a fix.
      expect(out.exitCode, ExitCode.ok);
      expect(out.toText(), contains('db/modules/sales'));
    });

    test('a mirrored api/db module pair is clean', () async {
      await scaffold();
      mkdirs('code/api/modules/sales');
      mkdirs('code/db/modules/sales');

      expect((await check()).deviations, 0);
    });

    test('a client module with no backend module of the same name warns',
        () async {
      await scaffold();
      mkdirs('code/api/modules/sales');
      mkdirs('code/db/modules/sales');
      mkdirs('code/app/modules/reporting');

      final out = await check();

      expect(out.deviations, 1);
      expect(out.toText(), contains('code/app/modules/reporting'));
    });

    test('a stray directory under code/ warns without failing', () async {
      await scaffold();
      mkdirs('code/legacy');

      final out = await check();

      expect(out.deviations, 1);
      expect(out.exitCode, ExitCode.ok);
      expect(out.toText(), contains('not a canonical layer'));
    });

    test('code/cli is a canonical optional surface, not a stray', () async {
      await scaffold();
      mkdirs('code/cli');

      expect((await check()).deviations, 0);
    });

    test('docs nested inside a layer warns', () async {
      await scaffold();
      mkdirs('code/api/docs');

      final out = await check();

      expect(out.deviations, 1);
      expect(out.toText(), contains('nested inside a layer'));
    });

    test('validate rejects a missing directory', () {
      final cmd = ProjectCheckCommand(
        ProjectCheckInput(resolvedPath: p.join(tempRoot.path, 'nowhere')),
      );
      expect(cmd.validate(), contains('No such directory'));
    });
  });

  // What `--plan` and `--apply` mean, that exactly one is required, that a
  // refusal changes nothing and that no terminal refuses rather than hangs —
  // none of that is tested here any more. The SDK applies all of it to every
  // command and has its own tests for it. Asserting it once per command tested
  // the SDK from thirteen places, and thirteen places is where it drifts.
  group('macss project adopt — what it would do', () {
    test('names every canon file it would create, and creates none', () async {
      Directory(dest).createSync(recursive: true);

      final previews = await plan();

      expect(previews.map((p) => p.target), contains('CHANGELOG.md'));
      expect(File(p.join(dest, 'CHANGELOG.md')).existsSync(), isFalse);
    });

    test('names the retirement before doing it', () async {
      await scaffold();
      File(p.join(dest, '.gitignore')).writeAsStringSync(
          '# MACSS — local workspace (git-ignored)\n.macss/\n');

      final previews = await plan();

      expect(previews.map((p) => p.verb), contains('retire'));
      expect(File(p.join(dest, '.gitignore')).readAsStringSync(),
          contains('.macss/'),
          reason: 'asking changes nothing');
    });

    test('a conforming, declared project would do nothing at all', () async {
      await scaffold();

      expect(await plan(), isEmpty);
    });
  });

  group('macss project adopt', () {
    test('creates what is missing and never overwrites', () async {
      Directory(dest).createSync(recursive: true);
      File(p.join(dest, 'README.md')).writeAsStringSync('MINE');

      final out = await adopt();

      expect(out.applied, isTrue);
      expect(out.created, isNot(contains('README.md')));
      expect(out.created.length, canonFiles.length - 1);
      expect(File(p.join(dest, 'README.md')).readAsStringSync(), 'MINE');
      expect((await check()).exitCode, ExitCode.ok);
    });

    test('never removes anything, including what check flags', () async {
      await scaffold();
      mkdirs('code/legacy');
      final marker = File(p.join(dest, 'code', 'legacy', 'keep.txt'));
      marker.writeAsStringSync('deliberate debt');

      await adopt();

      expect(marker.existsSync(), isTrue);
      expect(Directory(p.join(dest, 'code', 'legacy')).existsSync(), isTrue);
    });

    test('is a no-op on a conforming project', () async {
      await scaffold();

      final out = await adopt();

      expect(out.created, isEmpty);
      expect(out.applied, isFalse);
      expect(out.toText(), contains('Nothing to adopt'));
    });

    // The one thing adopt removes. ADR 0004 said it never deletes; that held
    // until the workspace began carrying its own ignore rule, which a root-level
    // `.macss/` renders dead letter — git does not descend into an excluded
    // directory, so the project's configuration could never be versioned.
    test('retires the obsolete workspace entry MACSS itself wrote', () async {
      await scaffold();
      final gitignore = File(p.join(dest, '.gitignore'));
      gitignore.writeAsStringSync('node_modules/\n'
          '\n'
          '# MACSS — local workspace (git-ignored)\n'
          '.macss/\n'
          'docs/requisitions/\n');

      final out = await adopt();

      final after = gitignore.readAsStringSync();
      expect(after, isNot(contains('.macss/')));
      expect(after, contains('docs/requisitions/'));
      expect(after, contains('node_modules/'),
          reason: 'what the project wrote is not ours to remove');
      expect(out.retired, isNotEmpty);
    });

    // Adopting the canon includes adopting the decision about language. A
    // project that predates this stops at the first document command until it
    // has been adopted, which is the contracted behaviour and the part a user
    // feels.
    test('declares the language on a project that had none', () async {
      await scaffold();

      await adopt(lang: 'es');

      expect(projectLanguage(dest), 'es');
    });

    test('a project already conforming but undeclared is not a no-op',
        () async {
      await scaffold();
      File(p.join(dest, '.macss', 'config.yaml')).deleteSync();

      final out = await adopt(lang: 'en');

      expect(out.applied, isTrue);
      expect(projectLanguage(dest), 'en');
    });

    test('the declaration is named before it is written', () async {
      await scaffold();
      File(p.join(dest, '.macss', 'config.yaml')).deleteSync();

      final previews = await plan(lang: 'es');

      expect(previews.firstWhere((p) => p.verb == 'declare').detail,
          contains('language: es'));
      expect(projectLanguage(dest), isNull, reason: 'asking changes nothing');
    });

    test('a project with nothing missing but a stale entry is not a no-op',
        () async {
      await scaffold();
      File(p.join(dest, '.gitignore')).writeAsStringSync(
          '# MACSS — local workspace (git-ignored)\n.macss/\n');

      final out = await adopt();

      expect(out.applied, isTrue);
    });

    test('nothing to adopt builds no steps at all', () async {
      await scaffold();

      expect(await plan(), isEmpty);
    });
  });

  // Contract style: through a real ModularCli, so parse-time enforcement is
  // exercised end to end without the compiled binary.
  group('macss project contract', () {
    // Adopting the canon includes adopting the decision about language, and
    // the refusal is the SDK enforcing the declared contract — so it is
    // exercised here, through a real CLI, and not against `validate()`.
    ModularCli makeCli({String? workingDirectory}) => ModularCli()
      ..module(
        'project',
        (m) => buildProjectModule(
          m,
          assets: assets,
          workingDirectory: workingDirectory,
        ),
      );

    test('check rejects an undeclared option', () async {
      final stderr = MemorySink();
      final code = await makeCli().run(
        ['project', 'check', '--path=$dest', '--bogus'],
        stdout: MemorySink().sink,
        stderr: stderr.sink,
      );

      expect(code, ExitCode.validationFailed);
      expect(await stderr.text(), contains('unknown option --bogus'));
    });

    test('without --lang it refuses, and adopts nothing', () async {
      Directory(dest).createSync(recursive: true);
      final stderr = MemorySink();

      final code = await makeCli().run(
        ['project', 'adopt', '--path=$dest', '--apply', '--autoapprove'],
        stdout: MemorySink().sink,
        stderr: stderr.sink,
      );

      final error = await stderr.text();
      expect(code, ExitCode.validationFailed);
      expect(error, contains('--lang'));
      expect(error, contains('a choice nobody made'));
      expect(File(p.join(dest, 'CHANGELOG.md')).existsSync(), isFalse);
    });

    // This used to assert that a bare `adopt` previews and exits 0. That was
    // the default ADR 0007 removes: it made "change nothing" the outcome of
    // forgetting a flag, so the safe path and the writing path were told apart
    // by an omission and the invocation recorded neither.
    test('adopt with neither flag is a usage error through the CLI', () async {
      Directory(dest).createSync(recursive: true);
      final stderr = MemorySink();

      final code = await makeCli().run(
        ['project', 'adopt', '--path=$dest', '--lang', 'en'],
        stdout: MemorySink().sink,
        stderr: stderr.sink,
      );

      expect(code, isNot(ExitCode.ok));
      expect(await stderr.text(), contains('--plan'));
      expect(File(p.join(dest, 'CHANGELOG.md')).existsSync(), isFalse);
    });

    // The invocation `macss project check` has been dictating all along, and
    // which used to fail with `unknown option --plan`.
    //
    // The plan lands where the command was invoked, so this needs an invoking
    // directory of its own. It is injected rather than assigned to
    // `Directory.current`: that is process-wide, `dart test` loads suites
    // concurrently in one process, and moving it out from under
    // `books_layout_test` — which resolves `../books` at load time — made that
    // suite fail at random.
    test('the command project check dictates is accepted', () async {
      Directory(dest).createSync(recursive: true);
      final invokedFrom = Directory(p.join(tempRoot.path, 'elsewhere'))
        ..createSync(recursive: true);

      final code = await makeCli(workingDirectory: invokedFrom.path).run(
        ['project', 'adopt', '--path=$dest', '--lang', 'en', '--plan'],
        stdout: MemorySink().sink,
        stderr: MemorySink().sink,
      );

      expect(code, ExitCode.ok);
      // Nothing reaches the target — not the canon, and not a workspace. Where
      // a plan file lands is the sink's business and is tested with the sink;
      // this CLI registers none, so `--plan` prints and files nothing.
      expect(File(p.join(dest, 'CHANGELOG.md')).existsSync(), isFalse);
      expect(Directory(p.join(dest, '.macss')).existsSync(), isFalse);
      expect(
          Directory(p.join(invokedFrom.path, '.macss')).existsSync(), isFalse);
    });

    test('create is reachable under the project module', () async {
      final code = await makeCli().run(
        ['project', 'create', '--path=$dest', '--lang', 'en', '--apply', '--autoapprove'],
        stdout: MemorySink().sink,
        stderr: MemorySink().sink,
      );

      expect(code, ExitCode.ok);
      expect(File(p.join(dest, 'CHANGELOG.md')).existsSync(), isTrue);
    });
  });
}
