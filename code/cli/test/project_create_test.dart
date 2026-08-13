import 'dart:io';

import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:modular_cli_sdk/testing.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/assets.dart';
import 'package:macss_cli/modules/project/commands/create.dart';
import 'package:macss_cli/modules/project/project_builder.dart';
import 'package:macss_cli/src/project_config.dart';

import 'support/memory_sink.dart';

void main() {
  late Directory tempRoot;
  late Directory assetsDir;
  late Assets assets;

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('macss_create_test_');

    // Build a minimal assets tree in a sibling dir
    assetsDir = Directory(p.join(tempRoot.path, '_assets'))
      ..createSync(recursive: true);
    assets = Assets(root: assetsDir.path);

    // Create fake templates
    final tplBase = p.join(
      assetsDir.path,
      'assets',
      'templates',
      'project-base',
    );
    _writeFile(
      p.join(tplBase, 'docs', 'adr', '0001-record-architecture-decisions.md'),
      '# ADR 0001',
    );
    _writeFile(p.join(tplBase, 'docs', 'architecture.md'), '# Architecture');
    _writeFile(p.join(tplBase, 'docs', 'roadmap.md'), '# Roadmap');
    for (final mod in ['infra', 'db', 'api', 'app']) {
      _writeFile(p.join(tplBase, 'code', mod, 'README.md'), '# $mod\n');
    }
    _writeFile(
      p.join(
        assetsDir.path,
        'assets',
        'templates',
        'project-base',
        'README.md',
      ),
      '# Project Name\n',
    );
    _writeFile(
      p.join(
        assetsDir.path,
        'assets',
        'templates',
        'project-base',
        '.gitignore',
      ),
      '.dart_tool/\nbuild/\n',
    );
    _writeFile(
      p.join(
        assetsDir.path,
        'assets',
        'templates',
        'project-base',
        '.gitattributes',
      ),
      '* text=auto eol=lf\n',
    );
    _writeFile(
      p.join(
        assetsDir.path,
        'assets',
        'templates',
        'project-base',
        'CHANGELOG.md',
      ),
      '# Changelog\n',
    );
  });

  tearDown(() {
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  CreateCommand makeCmd(String resolvedPath, {String? lang = 'en'}) =>
      CreateCommand(
        CreateInput(
          resolvedPath: resolvedPath,
          workingDirectory: tempRoot.path,
          lang: lang,
        ),
        assets: assets,
      );

  Future<CreateOutput> create(String dest, {String? lang = 'en'}) async =>
      await applyCommand(makeCmd(dest, lang: lang));

  /// What it says it would do. Nothing is scaffolded.
  Future<List<Preview>> plan(String dest, {String? lang = 'en'}) =>
      previewCommand(makeCmd(dest, lang: lang));

  // Wires the real module with the test assets, so contract parsing (abbr,
  // rejection) is exercised through the registration that actually ships —
  // rather than a local copy of it that could drift.
  ModularCli makeCli() =>
      ModularCli()
        ..module('project', (m) => buildProjectModule(m, assets: assets));

  group('macss project create contract', () {
    test('rejects an undeclared option before scaffolding', () async {
      final dest = p.join(tempRoot.path, 'reject-proj');
      final stderr = MemorySink();

      final code = await makeCli().run(
        ['project', 'create', '--path=$dest', '--bogus'],
        stdout: MemorySink().sink,
        stderr: stderr.sink,
      );

      expect(code, 7); // ExitCode.validationFailed
      expect(await stderr.text(), contains('unknown option --bogus'));
      expect(Directory(dest).existsSync(), isFalse); // never scaffolded
    });

    test('still accepts the -p abbreviation', () async {
      final dest = p.join(tempRoot.path, 'abbr-proj');

      final code = await makeCli().run(
        ['project', 'create', '-p', dest, '--lang', 'en', '--apply', '--autoapprove'],
        stdout: MemorySink().sink,
        stderr: MemorySink().sink,
      );

      expect(code, 0);
      expect(File(p.join(dest, 'README.md')).existsSync(), isTrue);
    });

    test('still accepts the --path option', () async {
      final dest = p.join(tempRoot.path, 'long-proj');

      final code = await makeCli().run(
        ['project', 'create', '--path=$dest', '--lang', 'en', '--apply', '--autoapprove'],
        stdout: MemorySink().sink,
        stderr: MemorySink().sink,
      );

      expect(code, 0);
      expect(File(p.join(dest, 'README.md')).existsSync(), isTrue);
    });

    // Scaffolding a whole project is the most consequential thing this CLI
    // does. It used to happen on a bare invocation.
    test('create with neither flag scaffolds nothing', () async {
      final dest = p.join(tempRoot.path, 'unasked-proj');
      final stderr = MemorySink();

      final code = await makeCli().run(
        ['project', 'create', '--path=$dest'],
        stdout: MemorySink().sink,
        stderr: stderr.sink,
      );

      expect(code, isNot(0));
      expect(await stderr.text(), contains('--plan'));
      expect(Directory(dest).existsSync(), isFalse);
    });
  });

  // A project declares the language of its documents once, and it is declared
  // at the moment it is chosen. There is no default: answering "English"
  // because nobody said is inventing a choice the caller was entitled to make
  // (ADR 0009).
  group('macss project create — the language is declared, never assumed', () {
    // Through the CLI, because the rule is now declared on the parameter and
    // the SDK enforces the declaration before the command is ever built.
    // Asserting it on `validate()` would test prose that no longer exists.
    test('without --lang it refuses, and scaffolds nothing', () async {
      final dest = p.join(tempRoot.path, 'undeclared-proj');
      final stderr = MemorySink();

      final code = await makeCli().run(
        ['project', 'create', '--path=$dest', '--apply', '--autoapprove'],
        stdout: MemorySink().sink,
        stderr: stderr.sink,
      );

      final error = await stderr.text();
      expect(code, ExitCode.validationFailed);
      expect(error, contains('--lang'));
      // The reason survives the move: it now reaches --help too, instead of
      // only the reader who already got it wrong.
      expect(error, contains('a choice nobody made'));
      expect(error, contains('required'));
      expect(Directory(dest).existsSync(), isFalse);
    });

    test('with --lang it writes the declaration', () async {
      final dest = p.join(tempRoot.path, 'declared-proj');

      await create(dest, lang: 'es');

      expect(projectLanguage(dest), 'es');
    });

    test('a language outside the shipped set is rejected, naming them',
        () async {
      final dest = p.join(tempRoot.path, 'fr-proj');
      final stderr = MemorySink();

      final code = await makeCli().run(
        ['project', 'create', '--path=$dest', '--lang', 'fr', '--apply'],
        stdout: MemorySink().sink,
        stderr: stderr.sink,
      );

      expect(code, isNot(0));
      final text = await stderr.text();
      expect(text, contains('en'));
      expect(text, contains('es'));
      expect(Directory(dest).existsSync(), isFalse);
    });

    test('the declaration is named in the plan before it is written', () async {
      final dest = p.join(tempRoot.path, 'planned-lang-proj');

      final previews = await plan(dest, lang: 'es');

      final declaration = previews.firstWhere((p) => p.verb == 'declare');
      expect(declaration.detail, contains('language: es'));
      expect(Directory(dest).existsSync(), isFalse);
    });
  });

  group('what macss project create would do', () {
    test('names the target and the canon, and creates neither', () async {
      final dest = p.join(tempRoot.path, 'planned-proj');

      final previews = await plan(dest);

      // The target is what `create` would bring into existence. Asking must
      // not bring it into existence to say so.
      expect(Directory(dest).existsSync(), isFalse);
      expect(previews.first.verb, 'create');
      expect(previews.first.target, dest);
      expect(previews.map((p) => p.target).join('\n'), contains('README.md'));
    });
  });

  group('macss project create', () {
    test('without --path it refuses, and scaffolds nothing', () async {
      final stderr = MemorySink();

      final code = await makeCli().run(
        ['project', 'create', '--lang', 'en', '--apply', '--autoapprove'],
        stdout: MemorySink().sink,
        stderr: stderr.sink,
      );

      expect(code, ExitCode.validationFailed);
      expect(await stderr.text(), contains('--path'));
    });

    test('creates root directory when it does not exist', () async {
      final dest = p.join(tempRoot.path, 'my-project');
      final output = await create(dest);

      expect(Directory(dest).existsSync(), isTrue);
      expect(output.exitCode, 0);
      expect(output.created, isTrue);
    });

    test(
      'stamps a README anchor in each module (survives first commit)',
      () async {
        final dest = p.join(tempRoot.path, 'proj');
        await create(dest);

        for (final mod in ['infra', 'db', 'api', 'app']) {
          expect(
            File(p.join(dest, 'code', mod, 'README.md')).existsSync(),
            isTrue,
            reason: 'code/$mod must have a README anchor',
          );
        }
      },
    );

    test('creates doc files from templates', () async {
      final dest = p.join(tempRoot.path, 'proj2');
      await create(dest);

      final adr = File(
        p.join(dest, 'docs', 'adr', '0001-record-architecture-decisions.md'),
      );
      final arch = File(p.join(dest, 'docs', 'architecture.md'));
      final road = File(p.join(dest, 'docs', 'roadmap.md'));

      expect(adr.existsSync(), isTrue);
      expect(arch.existsSync(), isTrue);
      expect(road.existsSync(), isTrue);
    });

    test('doc file content matches template', () async {
      final dest = p.join(tempRoot.path, 'proj3');
      await create(dest);

      final arch = File(p.join(dest, 'docs', 'architecture.md'));
      expect(arch.readAsStringSync(), '# Architecture');
    });

    test('does not overwrite existing files', () async {
      final dest = p.join(tempRoot.path, 'proj4');
      await create(dest);

      // Modify a file manually
      final arch = File(p.join(dest, 'docs', 'architecture.md'));
      arch.writeAsStringSync('# My custom content');

      // Run again
      await create(dest);

      expect(arch.readAsStringSync(), '# My custom content');
    });

    test('second run is idempotent and reports exists', () async {
      final dest = p.join(tempRoot.path, 'proj5');
      await create(dest);
      final output2 = await create(dest);

      expect(output2.exitCode, 0);
      expect(output2.toText(), contains('already initialized'));
    });

    test('fails with exitCode 2 when path is an existing file', () async {
      final filePath = p.join(tempRoot.path, 'not-a-dir.txt');
      File(filePath).writeAsStringSync('I am a file');

      await expectLater(
        create(filePath),
        throwsA(isA<CommandException>()
            .having((e) => e.exitCode, 'exitCode', 2)),
      );
    });

    test('works with absolute path', () async {
      final dest = p.join(tempRoot.path, 'abs-proj');
      final output = await create(dest);
      expect(output.exitCode, 0);
      expect(Directory(dest).existsSync(), isTrue);
    });

    test('creates README.md from template', () async {
      final dest = p.join(tempRoot.path, 'proj-readme');
      await create(dest);

      final readme = File(p.join(dest, 'README.md'));
      expect(readme.existsSync(), isTrue);
      expect(readme.readAsStringSync(), contains('# '));
    });

    test('creates .gitignore from template', () async {
      final dest = p.join(tempRoot.path, 'proj-gi');
      await create(dest);

      final gitignore = File(p.join(dest, '.gitignore'));
      expect(gitignore.existsSync(), isTrue);
      expect(gitignore.readAsStringSync(), isNotEmpty);
    });

    test('creates .gitattributes from template', () async {
      final dest = p.join(tempRoot.path, 'proj-ga');
      await create(dest);

      final gitattributes = File(p.join(dest, '.gitattributes'));
      expect(gitattributes.existsSync(), isTrue);
      expect(gitattributes.readAsStringSync(), contains('eol'));
    });

    test('does not deploy skills into the project', () async {
      // Skills are installed once per machine under the user's home, not per
      // repository — see `macss skill deploy`.
      final dest = p.join(tempRoot.path, 'proj-skills');
      await create(dest);

      expect(Directory(p.join(dest, '.skills')).existsSync(), isFalse);
    });

    test('does not overwrite existing README.md', () async {
      final dest = p.join(tempRoot.path, 'proj-no-overwrite');
      await create(dest);

      final readme = File(p.join(dest, 'README.md'));
      readme.writeAsStringSync('# Custom');

      await create(dest);
      expect(readme.readAsStringSync(), '# Custom');
    });
  });
}

void _writeFile(String path, String content) {
  Directory(p.dirname(path)).createSync(recursive: true);
  File(path).writeAsStringSync(content);
}
