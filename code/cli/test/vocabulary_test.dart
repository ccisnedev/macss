import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/assets.dart';
import 'package:macss_cli/src/vocabulary.dart';

/// The gate used to carry its keywords as Dart constants, in two different
/// shapes: a bilingual union for the scope headings and English-only for the
/// story labels, which is why the Spanish template had to embed
/// `**As a (Como)**`. Moving them to assets makes a new language one file plus
/// one template.
///
/// These tests **enumerate** `assets/vocabulary/` rather than listing languages,
/// so a language added tomorrow is covered by the suite it ships with.
void main() {
  final assets = Assets(root: Directory.current.path);

  group('shipped vocabularies', () {
    final languages = assets.listDirectoryFiles('vocabulary');

    test('at least English and Spanish ship', () {
      expect(languages, containsAll(<String>['en', 'es']));
    });

    for (final lang in languages) {
      test('$lang declares every key the gate needs', () {
        final vocabulary = Vocabularies.fromAssets(assets).forLanguage(lang);

        expect(vocabulary, isNotNull, reason: '$lang failed to load');
        for (final word in [
          vocabulary!.storyRole,
          vocabulary.storyWant,
          vocabulary.storyBenefit,
          vocabulary.scopeIncludes,
          vocabulary.scopeExcludes,
        ]) {
          expect(word.trim(), isNotEmpty);
        }
      });
    }
  });

  group('Vocabularies', () {
    test('the union carries every language\'s story labels', () {
      final all = Vocabularies.fromAssets(assets);

      // English is what the gate matched before; Spanish is what the template
      // had to embed English for.
      expect(all.storyRoles, containsAll(<String>['As a', 'Como']));
      expect(all.storyWants, containsAll(<String>['I want', 'Quiero']));
      expect(all.storyBenefits, containsAll(<String>['So that', 'Para']));
    });

    test('the union carries every language\'s scope headings', () {
      final all = Vocabularies.fromAssets(assets);

      expect(all.scopeIncludes, containsAll(<String>['Includes', 'Incluye']));
      expect(
        all.scopeExcludes,
        containsAll(<String>['Does NOT include', 'NO incluye']),
      );
    });

    test('an unknown language resolves to null, not to a wrong vocabulary', () {
      expect(Vocabularies.fromAssets(assets).forLanguage('xx'), isNull);
    });

    test('parses a vocabulary from yaml', () {
      final vocabulary = Vocabulary.fromYaml('''
story:
  role: "Als"
  want: "Ich will"
  benefit: "Damit"
scope:
  includes: "Enthält"
  excludes: "Enthält NICHT"
''');

      expect(vocabulary.storyRole, 'Als');
      expect(vocabulary.scopeExcludes, 'Enthält NICHT');
    });

    test('a vocabulary missing a key is rejected, not silently empty', () {
      // A half-written vocabulary would make the gate stop finding stories in
      // that language and report "no user stories" — a wrong answer rather than
      // an error.
      expect(
        () => Vocabulary.fromYaml('story:\n  role: "Als"\n'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Assets.listDirectoryFiles', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('macss_vocab_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('returns basenames without the extension, sorted', () {
      final dir = Directory(p.join(tempDir.path, 'assets', 'vocabulary'))
        ..createSync(recursive: true);
      for (final name in ['pt.yaml', 'en.yaml', 'de.yaml']) {
        File(p.join(dir.path, name)).writeAsStringSync('');
      }

      expect(
        Assets(root: tempDir.path).listDirectoryFiles('vocabulary'),
        ['de', 'en', 'pt'],
      );
    });

    test('ignores directories and other extensions', () {
      final dir = Directory(p.join(tempDir.path, 'assets', 'vocabulary'))
        ..createSync(recursive: true);
      File(p.join(dir.path, 'en.yaml')).writeAsStringSync('');
      File(p.join(dir.path, 'README.md')).writeAsStringSync('');
      Directory(p.join(dir.path, 'nested')).createSync();

      expect(Assets(root: tempDir.path).listDirectoryFiles('vocabulary'), ['en']);
    });
  });
}
