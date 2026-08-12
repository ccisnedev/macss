/// The verification method depends on nothing but a contract, a change and a
/// human — checked by machine, because a coupling is a word.
///
/// The abandoned draft written against the superseded contract knew about six
/// things outside verification: `delivery.md`, the pull request body, the
/// Definition of Ready, the Definition of Done, the state machine and the
/// `delivery` module. None of them helped it verify, and all of them made it
/// unusable where those stages do not exist.
///
/// A reader will not catch the seventh. It goes back in as one word, in one
/// sentence, six months from now, and it reads perfectly — which is the same
/// failure mode as a message dictating a command the CLI rejects.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  final file = File(p.join(
    Directory.current.path,
    'assets',
    'skills',
    'macss-verification',
    'SKILL.md',
  ));

  /// Terms naming a stage, an artifact or a command outside verification.
  ///
  /// Each was in the abandoned draft. This is the list of what was actually
  /// there, not a guess at what might be: a guessed list would grow forever and
  /// mean nothing.
  /// Two left this list when the commands that serve the stage were built:
  /// `macss ` and `pull request`. The method now opens its own record and
  /// publishes it, and it says where the record goes — instructing a stage
  /// without naming the tool that performs it is how a documented convention
  /// becomes one nobody follows (#39).
  ///
  /// **The other six stay.** Naming the commands of its own stage is not the
  /// same as knowing about the stages around it: what the implementer wrote,
  /// which gates sit either side, or what the harness does afterwards. Those
  /// were in the abandoned draft, none of them helped it verify, and all of
  /// them made it unusable where those stages do not exist.
  const foreign = <String, String>{
    'delivery.md': 'the artifact the implementer writes',
    'definition of ready': 'a gate before this stage',
    'definition of done': 'a gate after it',
    'state machine': 'the harness that may enforce this',
    'requisition': 'the stage where the request is written',
    'specification': 'the stage where the contract is written',
  };

  group('the verification method knows only verification', () {
    test('it names no other stage, artifact or command', () {
      expect(file.existsSync(), isTrue, reason: '${file.path} is not there');

      final lines = file.readAsLinesSync();

      // Pinned, so extraction breaking reads as failure rather than as success.
      // A check that reports only violations passes loudest once it has stopped
      // looking — the lesson from #39, applied before it costs anything.
      expect(
        lines.length,
        greaterThanOrEqualTo(100),
        reason: 'read ${lines.length} lines, which is fewer than this document '
            'is known to have — the check is most likely reading the wrong file',
      );

      final found = <String>[];
      for (var i = 0; i < lines.length; i++) {
        // The front matter names the skill, and the skill is called
        // `macss-verification`. That is its own name, not a reference out.
        if (lines[i].startsWith('name:') ||
            lines[i].startsWith('description:')) {
          continue;
        }
        final line = lines[i].toLowerCase();
        for (final entry in foreign.entries) {
          if (line.contains(entry.key)) {
            found.add('  line ${i + 1}: "${entry.key}" — ${entry.value}\n'
                '    ${lines[i].trim()}');
          }
        }
      }

      expect(
        found,
        isEmpty,
        reason: '\nThe method names something outside verification:\n\n'
            '${found.join('\n\n')}\n\n'
            'It must depend on nothing but the acceptance criteria, the '
            'delivered change and a human. Where those come from, and what '
            'happens to the work afterwards, belongs to whoever invokes it.',
      );
    });

    test('it says the agent may not conclude', () {
      // The one thing the document must say, asserted alongside the many it
      // must not: a check made only of prohibitions is satisfied by an empty
      // file.
      final text = file.readAsStringSync().toLowerCase();

      expect(text, contains('you do not conclude'));
      expect(text, contains('may not conclude'));
      expect(text, contains('does not complete'));
    });
  });
}
