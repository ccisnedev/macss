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
import 'package:macss_cli/src/plan_apply.dart';

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
      CreateInput(
        resolvedPath: dest,
        workingDirectory: tempRoot.path,
        flags: const ChangeFlags(apply: true, autoapprove: true),
      ),
      assets: assets,
    ).execute();
  }

  Future<ProjectCheckOutput> check() =>
      ProjectCheckCommand(ProjectCheckInput(resolvedPath: dest)).execute();

  /// Fixed so the plan file name is deterministic.
  DateTime clock() => DateTime(2026, 8, 4, 9, 30, 15);

  ProjectAdoptCommand adoptCommand({
    bool plan = false,
    bool apply = false,
    bool autoapprove = false,
    Approver? approver,
  }) =>
      ProjectAdoptCommand(
        ProjectAdoptInput(
          resolvedPath: dest,
          flags: ChangeFlags(
              plan: plan, apply: apply, autoapprove: autoapprove),
        ),
        assets: assets,
        approver: approver ?? (_) async => true,
        now: clock,
      );

  Future<ProjectAdoptOutput> adopt({
    bool plan = false,
    bool apply = false,
    bool autoapprove = false,
    Approver? approver,
  }) =>
      adoptCommand(
        plan: plan,
        apply: apply,
        autoapprove: autoapprove,
        approver: approver,
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

  // ADR 0007: neither --plan nor --apply is a default, and the two must not be
  // distinguishable by an omission.
  group('macss project adopt — choosing plan or apply', () {
    test('a bare invocation is a usage error naming both ways out', () {
      Directory(dest).createSync(recursive: true);

      final error = adoptCommand().validate();

      expect(error, isNotNull);
      expect(error, contains('--plan'));
      expect(error, contains('--apply'));
    });

    test('both at once is a usage error rather than a silent choice', () {
      Directory(dest).createSync(recursive: true);

      expect(adoptCommand(plan: true, apply: true).validate(),
          contains('Choose one'));
    });

    test('--autoapprove without --apply authorizes nothing', () {
      Directory(dest).createSync(recursive: true);

      expect(adoptCommand(plan: true, autoapprove: true).validate(),
          contains('authorizes nothing'));
    });

    // On its own it is still the missing choice that needs saying first —
    // there is no approval to transfer until something is being applied.
    test('--autoapprove alone is answered by the choice it lacks', () {
      Directory(dest).createSync(recursive: true);

      expect(adoptCommand(autoapprove: true).validate(),
          contains('Choose --plan or --apply'));
    });

    test('a legal combination passes validation', () {
      Directory(dest).createSync(recursive: true);

      expect(adoptCommand(plan: true).validate(), isNull);
      expect(adoptCommand(apply: true).validate(), isNull);
      expect(adoptCommand(apply: true, autoapprove: true).validate(), isNull);
    });
  });

  group('macss project adopt --plan', () {
    test('writes the plan file and changes nothing else', () async {
      Directory(dest).createSync(recursive: true);

      final out = await adopt(plan: true);

      expect(out.applied, isFalse);
      expect(out.created, isEmpty);
      expect(File(p.join(dest, 'CHANGELOG.md')).existsSync(), isFalse);

      expect(out.planPath, isNotNull);
      expect(File(out.planPath!).existsSync(), isTrue);
      expect(p.split(out.planPath!), contains('plans'));
    });

    // The point of the file: a preview that only ever existed as terminal
    // output could not be attached, diffed, or read by anyone who was not
    // there. So it has to stand on its own.
    test('the plan reads on its own, away from the terminal', () async {
      Directory(dest).createSync(recursive: true);

      final out = await adopt(plan: true);
      final plan = File(out.planPath!).readAsStringSync();

      expect(plan, contains('macss project adopt'));
      expect(plan, contains('CHANGELOG.md'));
      expect(plan, contains('Nothing was changed'));
      expect(plan, contains('--apply'));
    });

    test('two plans of the same command do not overwrite each other', () async {
      Directory(dest).createSync(recursive: true);

      final first = await adopt(plan: true);
      final second = await ProjectAdoptCommand(
        ProjectAdoptInput(
          resolvedPath: dest,
          flags: const ChangeFlags(plan: true),
        ),
        assets: assets,
        now: () => DateTime(2026, 8, 4, 9, 31, 0),
      ).execute();

      expect(second.planPath, isNot(first.planPath));
      expect(File(first.planPath!).existsSync(), isTrue);
    });
  });

  group('macss project adopt --apply', () {
    test('shows the plan and applies once approved', () async {
      Directory(dest).createSync(recursive: true);
      File(p.join(dest, 'README.md')).writeAsStringSync('MINE');
      var shown = '';

      final out = await adopt(
        apply: true,
        approver: (plan) async {
          shown = plan;
          return true;
        },
      );

      expect(shown, contains('CHANGELOG.md'),
          reason: 'the plan must reach the approver before anything is written');
      expect(out.applied, isTrue);
      expect(out.created, isNot(contains('README.md')));
      expect(out.created.length, canonFiles.length - 1);
      // An existing file is never overwritten.
      expect(File(p.join(dest, 'README.md')).readAsStringSync(), 'MINE');
      expect((await check()).exitCode, ExitCode.ok);
    });

    test('writes no plan file — the operator is looking at it', () async {
      Directory(dest).createSync(recursive: true);

      final out = await adopt(apply: true, autoapprove: true);

      expect(out.planPath, isNull);
      expect(Directory(p.join(dest, '.macss', 'plans')).existsSync(), isFalse);
    });

    test('a refusal changes nothing and exits non-zero', () async {
      Directory(dest).createSync(recursive: true);

      final out = await adopt(apply: true, approver: (_) async => false);

      expect(out.applied, isFalse);
      expect(out.created, isEmpty);
      expect(out.exitCode, isNot(ExitCode.ok));
      expect(File(p.join(dest, 'CHANGELOG.md')).existsSync(), isFalse);
    });

    test('--autoapprove applies without ever asking', () async {
      Directory(dest).createSync(recursive: true);
      var asked = false;

      final out = await adopt(
        apply: true,
        autoapprove: true,
        approver: (_) async {
          asked = true;
          return true;
        },
      );

      expect(asked, isFalse);
      expect(out.applied, isTrue);
      expect(File(p.join(dest, 'CHANGELOG.md')).existsSync(), isTrue);
    });

    // The failure --autoapprove exists to prevent: a skill that kept a bare
    // --apply would block on a read that never returns. Refusing is the only
    // outcome an agent can act on.
    test('with no terminal to approve from, it refuses instead of hanging',
        () async {
      Directory(dest).createSync(recursive: true);

      final out = await adopt(
        apply: true,
        approver: (_) async => throw const NoApproverAvailable(),
      );

      expect(out.exitCode, isNot(ExitCode.ok));
      expect(out.message, contains('--autoapprove'));
      expect(File(p.join(dest, 'CHANGELOG.md')).existsSync(), isFalse);
    });

    test('never removes anything, including what check flags', () async {
      await scaffold();
      mkdirs('code/legacy');
      final marker = File(p.join(dest, 'code', 'legacy', 'keep.txt'));
      marker.writeAsStringSync('deliberate debt');

      await adopt(apply: true, autoapprove: true);

      expect(marker.existsSync(), isTrue);
      expect(Directory(p.join(dest, 'code', 'legacy')).existsSync(), isTrue);
    });

    test('is a no-op on a conforming project', () async {
      await scaffold();

      final out = await adopt(apply: true, autoapprove: true);

      expect(out.created, isEmpty);
      expect(out.message, contains('Nothing to adopt'));
    });

    test('nothing to adopt writes no plan file either', () async {
      await scaffold();

      final out = await adopt(plan: true);

      expect(out.planPath, isNull);
      expect(Directory(p.join(dest, '.macss', 'plans')).existsSync(), isFalse);
    });
  });

  // Contract style: through a real ModularCli, so parse-time enforcement is
  // exercised end to end without the compiled binary.
  group('macss project contract', () {
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

    // This used to assert that a bare `adopt` previews and exits 0. That was
    // the default ADR 0007 removes: it made "change nothing" the outcome of
    // forgetting a flag, so the safe path and the writing path were told apart
    // by an omission and the invocation recorded neither.
    test('adopt with neither flag is a usage error through the CLI', () async {
      Directory(dest).createSync(recursive: true);
      final stderr = MemorySink();

      final code = await makeCli().run(
        ['project', 'adopt', '--path=$dest'],
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
        ['project', 'adopt', '--path=$dest', '--plan'],
        stdout: MemorySink().sink,
        stderr: MemorySink().sink,
      );

      expect(code, ExitCode.ok);
      expect(File(p.join(dest, 'CHANGELOG.md')).existsSync(), isFalse);
      // The plan is the only thing written, and not into the target.
      expect(Directory(p.join(dest, '.macss')).existsSync(), isFalse);
      expect(
          Directory(p.join(invokedFrom.path, '.macss', 'plans')).existsSync(),
          isTrue);
    });

    test('create is reachable under the project module', () async {
      final code = await makeCli().run(
        ['project', 'create', '--path=$dest', '--apply', '--autoapprove'],
        stdout: MemorySink().sink,
        stderr: MemorySink().sink,
      );

      expect(code, ExitCode.ok);
      expect(File(p.join(dest, 'CHANGELOG.md')).existsSync(), isTrue);
    });
  });
}
