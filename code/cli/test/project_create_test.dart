import 'dart:io';

import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/assets.dart';
import 'package:macss_cli/modules/project/commands/create.dart';
import 'package:macss_cli/modules/project/project_builder.dart';
import 'package:macss_cli/src/plan_apply.dart';

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

  CreateCommand makeCmd(
    String resolvedPath, {
    ChangeFlags flags = const ChangeFlags(apply: true, autoapprove: true),
  }) =>
      CreateCommand(
        CreateInput(
          resolvedPath: resolvedPath,
          workingDirectory: tempRoot.path,
          flags: flags,
        ),
        assets: assets,
        now: () => DateTime(2026, 8, 4, 9, 30, 15),
      );

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
        ['project', 'create', '-p', dest, '--apply', '--autoapprove'],
        stdout: MemorySink().sink,
        stderr: MemorySink().sink,
      );

      expect(code, 0);
      expect(File(p.join(dest, 'README.md')).existsSync(), isTrue);
    });

    test('still accepts the --path option', () async {
      final dest = p.join(tempRoot.path, 'long-proj');

      final code = await makeCli().run(
        ['project', 'create', '--path=$dest', '--apply', '--autoapprove'],
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

  group('macss project create --plan', () {
    test('writes the plan where invoked, not into the target', () async {
      final dest = p.join(tempRoot.path, 'planned-proj');

      final out =
          await makeCmd(dest, flags: const ChangeFlags(plan: true)).execute();

      // The target is what `create` would bring into existence. Planning must
      // not bring it into existence to say so.
      expect(Directory(dest).existsSync(), isFalse);
      expect(out.created, isFalse);
      expect(out.planPath, isNotNull);
      expect(p.isWithin(tempRoot.path, out.planPath!), isTrue);
      expect(File(out.planPath!).readAsStringSync(), contains('README.md'));
    });
  });

  group('macss project create', () {
    test('validate returns error when path is null', () {
      final cmd = CreateCommand(
        CreateInput(
          resolvedPath: null,
          workingDirectory: tempRoot.path,
          flags: const ChangeFlags(apply: true, autoapprove: true),
        ),
        assets: assets,
      );
      expect(cmd.validate(), isNotNull);
    });

    test('creates root directory when it does not exist', () async {
      final dest = p.join(tempRoot.path, 'my-project');
      final output = await makeCmd(dest).execute();

      expect(Directory(dest).existsSync(), isTrue);
      expect(output.exitCode, 0);
      expect(output.created, isTrue);
    });

    test(
      'stamps a README anchor in each module (survives first commit)',
      () async {
        final dest = p.join(tempRoot.path, 'proj');
        await makeCmd(dest).execute();

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
      await makeCmd(dest).execute();

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
      await makeCmd(dest).execute();

      final arch = File(p.join(dest, 'docs', 'architecture.md'));
      expect(arch.readAsStringSync(), '# Architecture');
    });

    test('does not overwrite existing files', () async {
      final dest = p.join(tempRoot.path, 'proj4');
      await makeCmd(dest).execute();

      // Modify a file manually
      final arch = File(p.join(dest, 'docs', 'architecture.md'));
      arch.writeAsStringSync('# My custom content');

      // Run again
      await makeCmd(dest).execute();

      expect(arch.readAsStringSync(), '# My custom content');
    });

    test('second run is idempotent and reports exists', () async {
      final dest = p.join(tempRoot.path, 'proj5');
      await makeCmd(dest).execute();
      final output2 = await makeCmd(dest).execute();

      expect(output2.exitCode, 0);
      expect(output2.message, contains('already initialized'));
    });

    test('fails with exitCode 2 when path is an existing file', () async {
      final filePath = p.join(tempRoot.path, 'not-a-dir.txt');
      File(filePath).writeAsStringSync('I am a file');

      final output = await makeCmd(filePath).execute();
      expect(output.exitCode, 2);
      expect(output.created, isFalse);
    });

    test('works with absolute path', () async {
      final dest = p.join(tempRoot.path, 'abs-proj');
      final output = await makeCmd(dest).execute();
      expect(output.exitCode, 0);
      expect(Directory(dest).existsSync(), isTrue);
    });

    test('creates README.md from template', () async {
      final dest = p.join(tempRoot.path, 'proj-readme');
      await makeCmd(dest).execute();

      final readme = File(p.join(dest, 'README.md'));
      expect(readme.existsSync(), isTrue);
      expect(readme.readAsStringSync(), contains('# '));
    });

    test('creates .gitignore from template', () async {
      final dest = p.join(tempRoot.path, 'proj-gi');
      await makeCmd(dest).execute();

      final gitignore = File(p.join(dest, '.gitignore'));
      expect(gitignore.existsSync(), isTrue);
      expect(gitignore.readAsStringSync(), isNotEmpty);
    });

    test('creates .gitattributes from template', () async {
      final dest = p.join(tempRoot.path, 'proj-ga');
      await makeCmd(dest).execute();

      final gitattributes = File(p.join(dest, '.gitattributes'));
      expect(gitattributes.existsSync(), isTrue);
      expect(gitattributes.readAsStringSync(), contains('eol'));
    });

    test('does not deploy skills into the project', () async {
      // Skills are installed once per machine under the user's home, not per
      // repository — see `macss skill deploy`.
      final dest = p.join(tempRoot.path, 'proj-skills');
      await makeCmd(dest).execute();

      expect(Directory(p.join(dest, '.skills')).existsSync(), isFalse);
    });

    test('does not overwrite existing README.md', () async {
      final dest = p.join(tempRoot.path, 'proj-no-overwrite');
      await makeCmd(dest).execute();

      final readme = File(p.join(dest, 'README.md'));
      readme.writeAsStringSync('# Custom');

      await makeCmd(dest).execute();
      expect(readme.readAsStringSync(), '# Custom');
    });
  });
}

void _writeFile(String path, String content) {
  Directory(p.dirname(path)).createSync(recursive: true);
  File(path).writeAsStringSync(content);
}
