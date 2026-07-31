import 'dart:io';

import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/assets.dart';
import 'package:macss_cli/modules/global/commands/create.dart';

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
    _writeFile(p.join(assetsDir.path, 'assets', 'templates', 'project-base', 'README.md'), '# Project Name\n');
    _writeFile(p.join(assetsDir.path, 'assets', 'templates', 'project-base', '.gitignore'), '.dart_tool/\nbuild/\n');
    _writeFile(p.join(assetsDir.path, 'assets', 'templates', 'project-base', '.gitattributes'), '* text=auto eol=lf\n');
    _writeFile(
      p.join(assetsDir.path, 'assets', 'skills', 'macss-specification', 'SKILL.md'),
      '# Specification skill\n',
    );
  });

  tearDown(() {
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  CreateCommand makeCmd(String resolvedPath) => CreateCommand(
    CreateInput(
      resolvedPath: resolvedPath,
      workingDirectory: tempRoot.path,
    ),
    assets: assets,
  );

  // Wires `create` through the SDK exactly as the global builder does, but with
  // the test assets — so contract parsing (abbr, rejection) is exercised end to
  // end without depending on the compiled binary's asset layout.
  ModularCli makeCli() => ModularCli()
    ..command<CreateInput, CreateOutput>(
      'create',
      (req) => CreateCommand(CreateInput.fromCliRequest(req), assets: assets),
      description: 'Scaffold a new MACSS project',
      params: CreateInput.params,
    );

  group('macss create contract', () {
    test('rejects an undeclared option before scaffolding', () async {
      final dest = p.join(tempRoot.path, 'reject-proj');
      final stderr = MemorySink();

      final code = await makeCli().run(
        ['create', '--path=$dest', '--bogus'],
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
        ['create', '-p', dest],
        stdout: MemorySink().sink,
        stderr: MemorySink().sink,
      );

      expect(code, 0);
      expect(File(p.join(dest, 'README.md')).existsSync(), isTrue);
    });

    test('still accepts the --path option', () async {
      final dest = p.join(tempRoot.path, 'long-proj');

      final code = await makeCli().run(
        ['create', '--path=$dest'],
        stdout: MemorySink().sink,
        stderr: MemorySink().sink,
      );

      expect(code, 0);
      expect(File(p.join(dest, 'README.md')).existsSync(), isTrue);
    });
  });

  group('macss create', () {
    test('validate returns error when path is null', () {
      final cmd = CreateCommand(
        CreateInput(resolvedPath: null, workingDirectory: tempRoot.path),
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

    test('stamps a README anchor in each module (survives first commit)', () async {
      final dest = p.join(tempRoot.path, 'proj');
      await makeCmd(dest).execute();

      for (final mod in ['infra', 'db', 'api', 'app']) {
        expect(
          File(p.join(dest, 'code', mod, 'README.md')).existsSync(),
          isTrue,
          reason: 'code/$mod must have a README anchor',
        );
      }
    });

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

    test('deploys the lifecycle skills into .skills/', () async {
      final dest = p.join(tempRoot.path, 'proj-skills');
      final out = await makeCmd(dest).execute();

      final skill =
          File(p.join(dest, '.skills', 'macss-specification', 'SKILL.md'));
      expect(skill.existsSync(), isTrue);
      expect(skill.readAsStringSync(), '# Specification skill\n');
      expect(out.message, contains('.skills/macss-specification/SKILL.md'));
    });

    test('scaffolds without skills when the assets ship none', () async {
      Directory(p.join(assetsDir.path, 'assets', 'skills'))
          .deleteSync(recursive: true);

      final dest = p.join(tempRoot.path, 'proj-no-skills');
      final out = await makeCmd(dest).execute();

      expect(out.created, isTrue);
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
