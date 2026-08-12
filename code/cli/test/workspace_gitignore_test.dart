import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/src/plan_apply.dart';
import 'package:macss_cli/src/workspace_dir.dart';
import 'package:macss_cli/modules/specification/workspace.dart';

/// `.macss/` ignores itself, and the questions are put to **git**.
///
/// Asserting the file's contents would only prove we wrote what we meant. It
/// would not prove git agrees, and those came apart once already: while the
/// project's root `.gitignore` carried `.macss/`, an inner `.gitignore` was dead
/// letter — git does not descend into an excluded directory, so no `!` inside it
/// can re-include anything.
///
/// So every ignore question here is answered by `git check-ignore`, and the
/// summary one by `git status`.
void main() {
  late Directory repo;

  setUp(() {
    repo = Directory.systemTemp.createTempSync('macss_ws_ignore_');
    final init = Process.runSync('git', ['init', '-q'], workingDirectory: repo.path);
    expect(init.exitCode, 0, reason: 'these tests need a real repository');
  });

  tearDown(() {
    if (repo.existsSync()) repo.deleteSync(recursive: true);
  });

  /// True when git ignores [relative]. `check-ignore` exits 0 when it does.
  bool ignored(String relative) =>
      Process.runSync('git', ['check-ignore', '-q', relative],
              workingDirectory: repo.path)
          .exitCode ==
      0;

  /// `-uall` matters: without it git collapses a directory holding nothing
  /// tracked into a single `?? .macss/` line, which hides which files inside
  /// are actually being offered — the very question these tests ask.
  List<String> statusLines() => (Process.runSync('git',
              ['status', '--porcelain', '-uall'], workingDirectory: repo.path)
          .stdout as String)
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  void writeInWorkspace(String relative, String content) {
    final f = File(p.join(repo.path, '.macss', p.joinAll(relative.split('/'))))
      ..parent.createSync(recursive: true);
    f.writeAsStringSync(content);
  }

  group('the workspace carries its own rule', () {
    test('creating it writes the rule inside it', () {
      ensureWorkspace(repo.path);

      final rule = File(p.join(repo.path, '.macss', '.gitignore'));
      expect(rule.existsSync(), isTrue);
    });

    // Without this the file that makes every other rule work is itself ignored,
    // never committed, and nobody who clones the project ever has it.
    test('the rule is itself versioned', () {
      ensureWorkspace(repo.path);

      expect(ignored('.macss/.gitignore'), isFalse);
    });

    test('local state is ignored', () {
      ensureWorkspace(repo.path);
      writeInWorkspace('active_requisition.yaml', 'slug: demo\n');
      writeInWorkspace('plans/20260805-120000-project-adopt.md', '# Plan\n');

      expect(ignored('.macss/active_requisition.yaml'), isTrue);
      expect(ignored('.macss/plans/20260805-120000-project-adopt.md'), isTrue);
    });

    test('the project configuration is versioned', () {
      ensureWorkspace(repo.path);
      writeInWorkspace('config.yaml', 'language: en\n');

      expect(ignored('.macss/config.yaml'), isFalse);
    });

    // The reason the rule is an allowlist. With a denylist, anything MACSS
    // invents here later would be committed until somebody remembered to add
    // it, and remembering is not a control.
    test('anything invented here later is ignored without being named', () {
      ensureWorkspace(repo.path);
      writeInWorkspace('something-nobody-has-written-yet.json', '{}\n');

      expect(ignored('.macss/something-nobody-has-written-yet.json'), isTrue);
    });

    test('nothing of the workspace shows up as pending, except what is kept',
        () {
      ensureWorkspace(repo.path);
      writeInWorkspace('active_requisition.yaml', 'slug: demo\n');
      writeInWorkspace('plans/a.md', '# Plan\n');
      writeInWorkspace('config.yaml', 'language: en\n');

      final macssLines =
          statusLines().where((l) => l.contains('.macss')).toList();

      expect(macssLines, isNotEmpty, reason: 'the kept files must be offered');
      for (final line in macssLines) {
        expect(
          line,
          anyOf(contains('.macss/.gitignore'), contains('.macss/config.yaml')),
          reason: 'unexpected workspace file offered to git: $line',
        );
      }
    });

    test('it is idempotent and does not overwrite a rule already there', () {
      ensureWorkspace(repo.path);
      final rule = File(p.join(repo.path, '.macss', '.gitignore'));
      rule.writeAsStringSync('${rule.readAsStringSync()}!keepme\n');

      ensureWorkspace(repo.path);

      expect(rule.readAsStringSync(), contains('!keepme'));
    });
  });

  group('both paths that create the workspace go through it', () {
    // The defect that produced this requirement: `--plan` in a project that had
    // never opened a requisition created `.macss/` with nothing ignoring it.
    test('writing a plan file leaves the workspace ignored', () {
      PlanFile.write(
        workingDirectory: repo.path,
        command: 'project adopt',
        body: 'would create CHANGELOG.md',
        now: DateTime(2026, 8, 5, 12, 0, 0),
      );

      expect(File(p.join(repo.path, '.macss', '.gitignore')).existsSync(),
          isTrue);
      final macssLines =
          statusLines().where((l) => l.contains('.macss')).toList();
      for (final line in macssLines) {
        expect(line, contains('.macss/.gitignore'));
      }
    });

    test('recording the active requisition leaves the workspace ignored', () {
      writeActiveRequisition(
        repo.path,
        slug: 'demo',
        relDir: 'docs/requisitions/20260805-demo',
        isoDate: '2026-08-05',
      );

      expect(File(p.join(repo.path, '.macss', '.gitignore')).existsSync(),
          isTrue);
      expect(ignored('.macss/active_requisition.yaml'), isTrue);
    });
  });

  group('without a repository', () {
    test('creating the workspace still works', () {
      final bare = Directory.systemTemp.createTempSync('macss_ws_nogit_');
      addTearDown(() => bare.deleteSync(recursive: true));

      expect(() => ensureWorkspace(bare.path), returnsNormally);
      expect(File(p.join(bare.path, '.macss', '.gitignore')).existsSync(),
          isTrue);
    });
  });
}
