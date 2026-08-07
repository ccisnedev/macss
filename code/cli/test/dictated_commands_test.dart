/// Every invocation this CLI puts in front of somebody is one the CLI accepts.
///
/// The rule has failed three times, each through a message that read correctly:
/// `project check` dictating `macss project adopt --plan` before that flag
/// existed, the banner dictating `macss upgrade` after ADR 0007 made the choice
/// mandatory, and `macss project adopt --plan` again once #24 made `--lang`
/// required. Reading is what failed, so nothing here reads: the judgement is
/// asked of the catalogue the CLI publishes about itself.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/macss_cli.dart';
import 'package:macss_cli/src/dictated_commands.dart';

import 'support/memory_sink.dart';

void main() {
  /// The package root, wherever the suite is run from.
  final root = Directory.current.path;

  /// The CLI's own account of what it accepts. Asked of the CLI, in process,
  /// so it cannot drift from the binary the way a fixture would.
  Future<List<CliRoute>> catalog() async {
    final stdout = MemorySink();
    final code = await runMacss(
      const ['help', '--json'],
      stdout: stdout.sink,
      stderr: MemorySink().sink,
    );
    expect(code, 0, reason: 'the catalogue is the source of every judgement');
    return parseCatalog(await stdout.text());
  }

  List<DictatedCommand> dictatedUnder(String relativeDir, String extension) {
    final dir = Directory(p.join(root, p.joinAll(relativeDir.split('/'))));
    return [
      for (final f in dir.listSync(recursive: true).whereType<File>())
        if (f.path.endsWith(extension))
          ...dictatedIn(f, relativeTo: root),
    ];
  }

  String report(Iterable<DictatedVerdict> rejected) =>
      '\n${rejected.join('\n\n')}\n\n'
      '${rejected.length} dictated invocation(s) the CLI would refuse.\n'
      'Somebody typing what they were told would get an error. Correct the '
      'message, or the command.';

  // Fetched once: the two tests must judge against the same account, and
  // asking twice would let them disagree.
  late List<CliRoute> catalogOf;
  setUpAll(() async => catalogOf = await catalog());

  group('every dictated command is accepted', () {
    test('in the messages this CLI prints', () async {
      final commands = dictatedUnder('lib', '.dart');

      // Pinned, so extraction silently breaking reads as a failure rather than
      // as success. A guard that reports only violations passes loudest when it
      // has stopped looking.
      expect(
        commands.length,
        greaterThanOrEqualTo(25),
        reason: 'extraction found ${commands.length} invocations under lib/, '
            'which is fewer than this CLI is known to dictate — the check has '
            'most likely stopped seeing them',
      );

      final rejected =
          commands.map((c) => judge(c, catalogOf)).where((v) => !v.accepted);
      expect(rejected, isEmpty, reason: report(rejected));
    });

    test('in the skills it ships to agents', () async {
      // The skills are shipped assets, installed by `skill deploy`. The reader
      // there is an agent, which cannot tell a rejected invocation from an
      // accepted one before running it.
      final commands = dictatedUnder('assets/skills', 'SKILL.md');

      expect(
        commands.length,
        greaterThanOrEqualTo(10),
        reason: 'extraction found ${commands.length} invocations in the '
            'shipped skills — fewer than they are known to instruct',
      );

      final rejected =
          commands.map((c) => judge(c, catalogOf)).where((v) => !v.accepted);
      expect(rejected, isEmpty, reason: report(rejected));
    });
  });

}
