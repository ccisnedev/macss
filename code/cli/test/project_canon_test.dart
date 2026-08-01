import 'dart:io';

import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/assets.dart';
import 'package:macss_cli/modules/project/canon.dart';
import 'package:macss_cli/modules/project/commands/adopt.dart';
import 'package:macss_cli/modules/project/commands/check.dart';
import 'package:macss_cli/modules/project/commands/create.dart';
import 'package:macss_cli/modules/project/project_builder.dart';

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
    await CreateCommand(
      CreateInput(resolvedPath: dest, workingDirectory: tempRoot.path),
      assets: assets,
    ).execute();
  }

  Future<ProjectCheckOutput> check() =>
      ProjectCheckCommand(ProjectCheckInput(resolvedPath: dest)).execute();

  Future<ProjectAdoptOutput> adopt({required bool apply}) =>
      ProjectAdoptCommand(
        ProjectAdoptInput(resolvedPath: dest, apply: apply),
        assets: assets,
      ).execute();

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
      expect(out.toText(), contains('macss project adopt --plan'));
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

  group('macss project adopt', () {
    test('previews by default and writes nothing', () async {
      Directory(dest).createSync(recursive: true);

      final out = await adopt(apply: false);

      expect(out.applied, isFalse);
      expect(out.created, isEmpty);
      expect(out.message, contains('would be created'));
      expect(File(p.join(dest, 'CHANGELOG.md')).existsSync(), isFalse);
    });

    test('--apply creates exactly what was missing', () async {
      Directory(dest).createSync(recursive: true);
      File(p.join(dest, 'README.md')).writeAsStringSync('MINE');

      final out = await adopt(apply: true);

      expect(out.applied, isTrue);
      expect(out.created, isNot(contains('README.md')));
      expect(out.created.length, canonFiles.length - 1);
      // An existing file is never overwritten.
      expect(File(p.join(dest, 'README.md')).readAsStringSync(), 'MINE');
      expect((await check()).exitCode, ExitCode.ok);
    });

    test('never removes anything, including what check flags', () async {
      await scaffold();
      mkdirs('code/legacy');
      final marker = File(p.join(dest, 'code', 'legacy', 'keep.txt'));
      marker.writeAsStringSync('deliberate debt');

      await adopt(apply: true);

      expect(marker.existsSync(), isTrue);
      expect(Directory(p.join(dest, 'code', 'legacy')).existsSync(), isTrue);
    });

    test('is a no-op on a conforming project', () async {
      await scaffold();

      final out = await adopt(apply: true);

      expect(out.created, isEmpty);
      expect(out.message, contains('Nothing to adopt'));
    });
  });

  // Contract style: through a real ModularCli, so parse-time enforcement is
  // exercised end to end without the compiled binary.
  group('macss project contract', () {
    ModularCli makeCli() => ModularCli()
      ..module('project', (m) => buildProjectModule(m, assets: assets));

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

    test('adopt without --apply writes nothing through the CLI', () async {
      Directory(dest).createSync(recursive: true);

      final code = await makeCli().run(
        ['project', 'adopt', '--path=$dest'],
        stdout: MemorySink().sink,
        stderr: MemorySink().sink,
      );

      expect(code, ExitCode.ok);
      expect(File(p.join(dest, 'CHANGELOG.md')).existsSync(), isFalse);
    });

    test('create is reachable under the project module', () async {
      final code = await makeCli().run(
        ['project', 'create', '--path=$dest'],
        stdout: MemorySink().sink,
        stderr: MemorySink().sink,
      );

      expect(code, ExitCode.ok);
      expect(File(p.join(dest, 'CHANGELOG.md')).existsSync(), isTrue);
    });
  });
}
