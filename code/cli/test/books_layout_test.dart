import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The books carry the same promise the vocabulary assets do: **adding a
/// language is adding a directory**, and nothing in code has to learn its name.
///
/// That promise only holds if something checks it. `SUMMARY.md` lists the
/// chapters once, for every edition; if one language silently lacks a chapter,
/// the reader of that edition finds a gap and no one else finds anything.
///
/// These tests **enumerate** `code/books/*` and `src/*` rather than listing the
/// books and languages that exist today, so a book or an edition added tomorrow
/// is covered by the suite it ships with.
void main() {
  // Tests run from code/cli; the books are two levels up.
  //
  // This path is relative, and it is enumerated below at **registration** time,
  // not inside a test body — the groups are generated per book. So this suite
  // reads the process's working directory as it loads. `dart test` loads suites
  // concurrently in one process, which means any other suite that assigns to
  // `Directory.current` can make this one fail to load, at random and with no
  // hint of where it came from. One did, briefly. Inject a working directory
  // instead of moving the process's.
  final booksRoot = Directory(p.join('..', 'books'));

  /// The chapter slugs `SUMMARY.md` declares, in order.
  ///
  /// Entries are bare slugs rather than links: a title is language-dependent
  /// and a slug is not, so the title lives in each chapter's own H1.
  List<String> slugsOf(Directory book) {
    final summary = File(p.join(book.path, 'SUMMARY.md'));
    if (!summary.existsSync()) return const [];

    return summary
        .readAsLinesSync()
        .map((l) => l.trim())
        .where((l) => l.startsWith('- '))
        .map((l) => l.substring(2).trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  List<Directory> booksIn(Directory root) => root
      .listSync()
      .whereType<Directory>()
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  List<String> languagesOf(Directory book) {
    final src = Directory(p.join(book.path, 'src'));
    if (!src.existsSync()) return const [];
    return src.listSync().whereType<Directory>().map((d) => p.basename(d.path)).toList()
      ..sort();
  }

  group('the books directory', () {
    test('there are books to check', () {
      expect(booksRoot.existsSync(), isTrue,
          reason: 'expected the books at ${booksRoot.absolute.path}');
      expect(booksIn(booksRoot), isNotEmpty);
    });

    for (final book in booksIn(booksRoot)) {
      final name = p.basename(book.path);

      group(name, () {
        test('declares its reading order in SUMMARY.md', () {
          expect(File(p.join(book.path, 'SUMMARY.md')).existsSync(), isTrue);
        });

        test('SUMMARY lists slugs, not titles or links', () {
          // `- [Glosario MACSS](glossary.md)` would put a Spanish title in the
          // file every language shares, which is the drift this layout exists
          // to prevent.
          for (final slug in slugsOf(book)) {
            expect(slug, matches(RegExp(r'^[a-z0-9][a-z0-9-]*$')),
                reason: '"$slug" is not a bare slug');
          }
        });

        test('every language has every chapter', () {
          final slugs = slugsOf(book);
          final languages = languagesOf(book);
          if (slugs.isEmpty) return; // a book not written yet is not a failure

          expect(languages, isNotEmpty,
              reason: '$name declares chapters but ships no src/<lang>/');

          for (final lang in languages) {
            for (final slug in slugs) {
              expect(
                File(p.join(book.path, 'src', lang, '$slug.md')).existsSync(),
                isTrue,
                reason: '$name has no $lang translation of "$slug"',
              );
            }
          }
        });

        test('no chapter exists that SUMMARY does not declare', () {
          // An orphan file is a chapter nobody reads: the reading order is the
          // only thing that puts a chapter in front of anyone.
          final slugs = slugsOf(book).toSet();
          for (final lang in languagesOf(book)) {
            final dir = Directory(p.join(book.path, 'src', lang));
            for (final f in dir.listSync().whereType<File>()) {
              if (p.extension(f.path) != '.md') continue;
              expect(slugs, contains(p.basenameWithoutExtension(f.path)),
                  reason: '${p.basename(f.path)} ($lang) is not in SUMMARY.md');
            }
          }
        });
      });
    }
  });

  group('the slug parser reads a SUMMARY as it is actually written', () {
    test('takes bullets and ignores the header and comments', () {
      final tmp = Directory.systemTemp.createTempSync('macss_books_test_');
      addTearDown(() => tmp.deleteSync(recursive: true));

      File(p.join(tmp.path, 'SUMMARY.md')).writeAsStringSync('''
# Summary

<!-- a comment that is not a chapter -->

- part-i
- introduction

- part-ii
''');

      expect(slugsOf(tmp), ['part-i', 'introduction', 'part-ii']);
    });
  });
}
