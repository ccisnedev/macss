import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/src/project_config.dart';

/// A project says what language its documents are in, once, and the answer
/// travels with the repository.
///
/// It used to be passed per invocation, so a project could drift one issue at a
/// time and no gate could see it — `modular_cli_sdk`, an English repository, had
/// its first requisition opened in Spanish against the command's own default,
/// and nothing objected.
///
/// A project that has not declared one does **not** get a sensible fallback:
/// ADR 0009 holds that a default may derive a value the caller already
/// established, and may never invent one. English-because-nobody-said is an
/// invention.
void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('macss_config_'));
  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  File configFile() =>
      File(p.join(root.path, '.macss', 'config.yaml'));

  group('reading', () {
    test('a project that declared its language answers with it', () {
      writeProjectConfig(root.path, language: 'es');

      expect(projectLanguage(root.path), 'es');
    });

    test('a project that declared nothing answers nothing', () {
      expect(projectLanguage(root.path), isNull);
    });

    test('a workspace with no config answers nothing, and does not throw', () {
      Directory(p.join(root.path, '.macss')).createSync(recursive: true);

      expect(projectLanguage(root.path), isNull);
    });
  });

  group('writing', () {
    test('holds the language and nothing else', () {
      writeProjectConfig(root.path, language: 'en');

      final keys = configFile()
          .readAsLinesSync()
          .where((l) => l.trim().isNotEmpty && !l.trim().startsWith('#'))
          .map((l) => l.split(':').first.trim())
          .toList();

      expect(keys, ['language']);
    });

    test('creates the workspace if it is not there', () {
      writeProjectConfig(root.path, language: 'en');

      expect(configFile().existsSync(), isTrue);
    });

    // #21: the workspace ignores itself with an allowlist, and this file is one
    // of the two exceptions. Without that, a project's declared language would
    // not survive a clone — which is the whole point of writing it down.
    test('lands where the workspace keeps what is versioned', () {
      writeProjectConfig(root.path, language: 'en');

      final rule =
          File(p.join(root.path, '.macss', '.gitignore')).readAsStringSync();

      expect(rule, contains('!config.yaml'));
    });

    test('rewriting replaces the declaration rather than appending', () {
      writeProjectConfig(root.path, language: 'en');
      writeProjectConfig(root.path, language: 'es');

      expect(projectLanguage(root.path), 'es');
      expect(
          RegExp('language:', multiLine: true)
              .allMatches(configFile().readAsStringSync())
              .length,
          1);
    });
  });

  group('the failure a command reports when nothing is declared', () {
    test('names the command that resolves it', () {
      final failure = undeclaredLanguageFailure(root.path);

      expect(failure, isNotNull);
      expect(failure, contains('project adopt'));
      expect(failure, contains('--lang'));
    });

    test('is silent once the project has declared one', () {
      writeProjectConfig(root.path, language: 'en');

      expect(undeclaredLanguageFailure(root.path), isNull);
    });

    // A directory that is not a MACSS project and a project opened before this
    // change are the same fact from the command's side: there is no language to
    // resolve a template with. One message, not two.
    test('does not distinguish a stale project from a bare directory', () {
      final bare = Directory.systemTemp.createTempSync('macss_bare_');
      addTearDown(() => bare.deleteSync(recursive: true));

      expect(undeclaredLanguageFailure(bare.path),
          undeclaredLanguageFailure(root.path));
    });
  });
}
