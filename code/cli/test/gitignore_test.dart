import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/src/gitignore.dart';

/// MACSS retires what MACSS wrote, and nothing else.
///
/// `ensureGitignoreEntries` only ever appended. Retiring is new, and it is the
/// first time this CLI removes a line from a file the project owns — so the
/// boundary matters more than the removal: an entry under the MACSS header is
/// machine-written output, the same argument by which `skill deploy` prunes the
/// `macss-` namespace. A rule the project wrote is not ours.
void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('macss_gitignore_'));
  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  File gitignore() => File(p.join(root.path, '.gitignore'));
  void write(String content) => gitignore().writeAsStringSync(content);

  group('what the root still carries', () {
    test('reports a retired entry that is present', () {
      write('# MACSS — local workspace (git-ignored)\n'
          '.macss/\n'
          'docs/requisitions/\n');

      expect(retiredGitignoreEntriesIn(root.path), ['.macss/']);
    });

    test('reports nothing when it is already gone', () {
      write('docs/requisitions/\n');

      expect(retiredGitignoreEntriesIn(root.path), isEmpty);
    });

    test('reports nothing when there is no .gitignore at all', () {
      expect(retiredGitignoreEntriesIn(root.path), isEmpty);
    });
  });

  group('retiring', () {
    test('removes the entry and keeps the one still managed', () {
      write('# MACSS — local workspace (git-ignored)\n'
          '.macss/\n'
          'docs/requisitions/\n');

      final status = removeGitignoreEntries(root.path);

      expect(status, isNotNull);
      expect(gitignore().readAsStringSync(), isNot(contains('.macss/')));
      expect(gitignore().readAsStringSync(), contains('docs/requisitions/'));
    });

    // The licence for touching this file is that MACSS wrote the line. Anything
    // else in it belongs to the project and has to come out untouched.
    test('leaves everything the project wrote byte for byte', () {
      const foreign = 'node_modules/\n'
          '*.log\n'
          '\n'
          '# my own section\n'
          '.env.local\n';
      write('$foreign# MACSS — local workspace (git-ignored)\n'
          '.macss/\n'
          'docs/requisitions/\n');

      removeGitignoreEntries(root.path);

      expect(gitignore().readAsStringSync(), startsWith(foreign));
    });

    test('a rule that merely mentions the text is not an entry', () {
      write('# MACSS — local workspace (git-ignored)\n'
          'docs/requisitions/\n'
          '\n'
          '!.macss/keep-this\n');

      removeGitignoreEntries(root.path);

      expect(gitignore().readAsStringSync(), contains('!.macss/keep-this'));
    });

    test('a header left describing nothing goes with its entries', () {
      write('node_modules/\n'
          '\n'
          '# MACSS — local workspace (git-ignored)\n'
          '.macss/\n');

      removeGitignoreEntries(root.path);

      final after = gitignore().readAsStringSync();
      expect(after, isNot(contains('MACSS')));
      expect(after, contains('node_modules/'));
    });

    test('is idempotent, and reports nothing when there was nothing to do', () {
      write('docs/requisitions/\n');

      expect(removeGitignoreEntries(root.path), isNull);
      expect(gitignore().readAsStringSync(), 'docs/requisitions/\n');
    });

    test('does nothing when there is no .gitignore', () {
      expect(removeGitignoreEntries(root.path), isNull);
      expect(gitignore().existsSync(), isFalse);
    });
  });

  group('what the root is still asked to ignore', () {
    // `.macss/` had to leave: while the root excluded the directory, git never
    // descended into it, so the workspace's own rule was dead letter.
    test('no longer includes the workspace', () {
      expect(macssGitignoreEntries, isNot(contains('.macss/')));
    });

    test('still includes the requisitions workspace, which lives outside it',
        () {
      expect(macssGitignoreEntries, contains('docs/requisitions/'));
    });
  });
}
