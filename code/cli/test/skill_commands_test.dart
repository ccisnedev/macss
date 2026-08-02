import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/assets.dart';
import 'package:macss_cli/macss_cli.dart';

import 'support/memory_sink.dart';

/// A skill is not documentation: it is an instruction a model will **execute**.
///
/// `macss-specification` shipped for a release telling the model to run
/// `macss issue new` and `macss issue publish`, commands removed in 0.4.0. Every
/// test passed, because nothing connected what the skills say to what the CLI
/// accepts.
///
/// This is the same guard `help_command_test` provides for the catalogue, aimed
/// at the skills: every `macss <…>` a skill names must be a route the CLI has.
void main() {
  final assets = Assets(root: Directory.current.path);

  /// Every route the CLI registers, from its own machine-readable catalogue.
  Future<Set<String>> routes() async {
    final stdout = MemorySink();
    await runMacss(const ['help', '--json'],
        stdout: stdout.sink, stderr: MemorySink().sink);

    final catalog = jsonDecode(await stdout.text()) as Map<String, dynamic>;
    return (catalog['commands'] as List)
        .cast<Map<String, dynamic>>()
        .map((c) => c['route'] as String)
        // Routes carry their positional placeholders (`new <slug>`); the skills
        // name the command, so compare on the command part.
        .map((r) => r.split(' <').first.trim())
        .toSet();
  }

  /// The `macss <module> <action>` invocations a skill text names.
  Set<String> commandsNamedIn(String skill) => RegExp(r'`macss ([a-z][a-z -]*)`')
      .allMatches(skill)
      .map((m) => m.group(1)!.trim())
      // Drop flags and arguments: `macss requisition publish --plan` names the
      // command `requisition publish`.
      .map((c) => c.split(' --').first.trim())
      .where((c) => c.isNotEmpty)
      .toSet();

  group('every command a skill names exists', () {
    final skills = assets.listDirectory('skills');

    test('there are skills to check', () {
      expect(skills, isNotEmpty);
    });

    for (final name in skills) {
      test(name, () async {
        final text = assets.loadString('skills/$name/SKILL.md');
        final available = await routes();

        for (final command in commandsNamedIn(text)) {
          expect(
            available,
            contains(command),
            reason: '$name tells the model to run `macss $command`, '
                'which the CLI does not accept',
          );
        }
      });
    }
  });

  group('the parser reads what a skill actually looks like', () {
    test('picks up a command with flags', () {
      expect(
        commandsNamedIn('run `macss requisition publish --apply` to create it'),
        {'requisition publish'},
      );
    });

    test('picks up a bare command', () {
      expect(commandsNamedIn('then `macss dor check`'), {'dor check'});
    });

    test('ignores prose that merely mentions macss', () {
      expect(commandsNamedIn('the MACSS vertical, macss layers'), isEmpty);
    });
  });

  group('the skills describe the flow that exists', () {
    test('none of them names a command removed with the one-to-one model',
        () async {
      // covers:, spec: and the issue module went when one specification stopped
      // deriving many issues.
      for (final name in assets.listDirectory('skills')) {
        final text = assets.loadString('skills/$name/SKILL.md');

        for (final gone in const ['macss issue new', 'macss issue publish']) {
          expect(text, isNot(contains(gone)), reason: '$name is stale');
        }
        expect(text, isNot(contains('covers:')), reason: '$name is stale');
      }
    });

    test('the specification skill walks the whole stage', () async {
      final text = assets.loadString('skills/macss-specification/SKILL.md');

      // The stage runs requisition -> specification -> DoR. A skill naming only
      // the middle of it leaves the model to guess the ends.
      for (final step in const [
        'macss requisition new',
        'macss requisition check',
        'macss requisition publish',
        'macss specification new',
        'macss specification check',
        'macss specification publish',
        'macss dor check',
      ]) {
        expect(text, contains(step), reason: 'the stage skips $step');
      }
    });
  });

  group('shipped skills are wired into the CLI', () {
    test('doctor verifies every one of them', () {
      // A skill that ships but is not checked can go missing from an install
      // without anything noticing.
      final doctor = File(
        p.join('lib', 'modules', 'global', 'commands', 'doctor.dart'),
      ).readAsStringSync();

      for (final name in assets.listDirectory('skills')) {
        expect(doctor, contains('skills/$name/SKILL.md'),
            reason: '$name is not in doctor\'s asset list');
      }
    });
  });
}
