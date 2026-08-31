import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The installer people run is the one the site serves, and there is only one.
///
/// This repository carried two copies of each installer — `code/cli/scripts/`
/// and `code/site/` — and they diverged. The site's `install.ps1` wrote a `ma`
/// alias that invoked a bare `macss`, which resolves through PATH and can run a
/// different installation than the one just unpacked. The repository copy had
/// been fixed, and carried the comment explaining why. The fix never reached
/// the copy anybody actually runs.
///
/// That is the general shape rather than an accident: **the drifted copy is
/// always the one in production, because production is the copy nobody edits.**
/// A test that the two agree would have caught it, and would also have left two
/// files to keep agreeing. One file cannot disagree with itself.
///
/// These tests **enumerate** the repository rather than naming the paths that
/// exist today, so a third copy added tomorrow fails on the day it is added.
void main() {
  // Tests run from code/cli.
  final repoRoot = Directory(p.join('..', '..'));

  /// Directories that are not source: caches, build output, and the vendored
  /// tree the VS Code integration test downloads, which ships installers of its
  /// own that are nobody's business here.
  const skipped = {
    '.git',
    '.dart_tool',
    'build',
    'node_modules',
    '.vscode-test',
  };

  List<String> findByName(String name) {
    final found = <String>[];

    void walk(Directory dir) {
      for (final entity in dir.listSync(followLinks: false)) {
        final base = p.basename(entity.path);
        if (entity is Directory) {
          if (skipped.contains(base)) continue;
          walk(entity);
        } else if (entity is File && base == name) {
          found.add(p.relative(entity.path, from: repoRoot.path).replaceAll(r'\', '/'));
        }
      }
    }

    walk(repoRoot);
    found.sort();
    return found;
  }

  group('one installer per platform, and the site owns it', () {
    for (final name in const ['install.ps1', 'install.sh']) {
      test('$name exists exactly once', () {
        final found = findByName(name);
        expect(
          found,
          hasLength(1),
          reason: 'Found ${found.length} copies of $name: $found. '
              'The release installer belongs in code/site/, which is the only '
              'place it is served from. Development scripts are dev-install.*.',
        );
      });

      test('$name is the one the site serves', () {
        expect(findByName(name), ['code/site/$name']);
      });
    }
  });

  group('the alias never resolves through PATH', () {
    // `ma` must run the macss that was just unpacked, not whichever macss the
    // PATH happens to find first. On Windows that means %~dp0 — the directory
    // of the .cmd itself; on Linux a symlink to an absolute path.
    test('install.ps1 builds ma.cmd from its own directory', () {
      final script = File(p.join('..', 'site', 'install.ps1')).readAsStringSync();
      final aliasLine = script
          .split('\n')
          // The line that *writes* the file, not the comment above it.
          // Matching `ma.cmd` alone finds the comment first and then asserts
          // against it, which passes or fails for reasons that have nothing to
          // do with the alias.
          .firstWhere(
            (l) => l.contains('ma.cmd') && l.contains('Set-Content'),
            orElse: () => '',
          );

      expect(aliasLine, isNotEmpty, reason: 'install.ps1 no longer writes ma.cmd');
      expect(
        aliasLine,
        contains(r'%~dp0'),
        reason: 'ma.cmd invokes a bare command, which PATH resolves to '
            'whichever installation comes first. It must call the macss.exe '
            'sitting beside it.',
      );
    });

    test('install.sh links ma to an absolute path', () {
      final script = File(p.join('..', 'site', 'install.sh')).readAsStringSync();
      expect(script, contains(r'ln -sf "$BIN_DIR/macss" "$BIN_DIR/ma"'));
    });
  });
}
