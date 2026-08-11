/// The specification method names its two actors and the acts they perform.
///
/// The skill as it shipped before #44 satisfied none of the twenty-six criteria
/// agreed there. Measured rather than asserted: ten of the twelve concepts the
/// contract requires appeared zero times, and the whole contract stage was one
/// imperative — "Fill `specification.md`" — addressed to one person, producing
/// everything at once. That is the corpus the requisition exists to prevent,
/// prescribed by the method itself.
///
/// A reader will not catch a word going missing. These are the words the
/// criteria turn on, and a rewrite that drops one reads perfectly.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  final file = File(p.join(
    Directory.current.path,
    'assets',
    'skills',
    'macss-specification',
    'SKILL.md',
  ));

  /// What the contract requires the method to speak about, with the criterion
  /// that requires it. Taken from the diagnosis's own measurement — these are
  /// the concepts that were absent, not a guess at what might be.
  const required = <String, String>{
    'authoriz': 'US-3 — there is a second actor, and it authorizes',
    'inventory': 'US1-AC1 — the sources are inventoried',
    'one at a time': 'US3-AC2 — criteria are confirmed one at a time',
    'objectively': 'US5-AC1 — a criterion is objectively checkable',
    'contradict': 'US5-AC2 — and contradicts none already agreed',
    'means to check': 'US6-AC1 — every claim arrives with what checks it',
    'observable': 'US7-AC2 — what would have to be observable',
  };

  /// The sentence the contract retires, and the reason it is a test and not a
  /// deletion: size depends on circumstance the method has no access to, and
  /// somebody restores a lost-looking sentence a year later.
  const retired = 'too large to deliver as a unit';

  group('the specification method', () {
    test('names the actors and the acts the contract requires', () {
      expect(file.existsSync(), isTrue, reason: '${file.path} is not there');

      final lines = file.readAsLinesSync();

      // Pinned, so extraction breaking reads as failure rather than success.
      // The lesson from #39, and the same shape as the verification guard.
      expect(
        lines.length,
        greaterThanOrEqualTo(60),
        reason: 'read ${lines.length} lines, fewer than any shipped skill — '
            'the check is most likely reading the wrong file',
      );

      final text = lines.join('\n').toLowerCase();
      final missing = <String>[
        for (final entry in required.entries)
          if (!text.contains(entry.key)) '  "${entry.key}" — ${entry.value}',
      ];

      expect(
        missing,
        isEmpty,
        reason: '\nThe method does not speak about:\n\n${missing.join('\n')}\n\n'
            'Each is a criterion of #44 that the document would silently not '
            'meet. A rewrite that drops one of these reads perfectly.',
      );
    });

    test('does not tell anyone to split a request by its size', () {
      final text = file.readAsStringSync().toLowerCase();

      expect(
        text,
        isNot(contains(retired)),
        reason: '\nThe method tells someone to split a request that is "$retired".\n'
            'Retired by #44: size depends on how busy the team is, which the '
            'method has no access to. Splitting is a business decision.\n'
            'This is a test rather than a deletion because a sentence that '
            'looks lost gets restored.',
      );
    });

    // The one thing worth keeping from the version that shipped before #44.
    test('keeps the principle that unobservable value is the finding', () {
      final text = file.readAsStringSync().toLowerCase();

      expect(text, contains('vapour'));
      expect(text, contains('rethinking'));
    });
  });
}
