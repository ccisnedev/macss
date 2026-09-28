import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:macss_cli/macss_cli.dart';

import 'support/memory_sink.dart';

/// Every `macss ...` invocation this repository suggests to a person or an
/// agent, whether in a hint string a failed command prints, a doc comment, or
/// a shipped asset (a skill, a README, an architecture doc), must be one
/// `cli_router` 0.2.0 actually accepts.
///
/// `cli_router` 0.2.0 rejects an option that follows a positional operand
/// (`misplaced-option`): `macss requisition new demo --apply` no longer
/// works, only `macss requisition new --apply demo` does. That rule is
/// accepted as-is (see CHANGELOG.md); what is not acceptable is this
/// repository still telling people and agents to type the invalid order.
///
/// This scans the CLI's own source and shipped docs for suggested command
/// lines, and for every one whose positional comes before an option, runs it
/// (with its placeholder filled in) through the real router and asserts it
/// is not rejected as a parse error. A line that fails for an unrelated,
/// expected reason (no active requisition, not inside a project) is fine:
/// this only guards against the CLI training its own users to type something
/// the parser refuses outright.
void main() {
  test(
    'every suggested requisition command puts its options before its slug',
    () async {
      final root = _repoRoot();
      final suggestions = _suggestedCommands(root);

      expect(
        suggestions,
        isNotEmpty,
        reason:
            'found no `macss requisition new/activate ...` suggestion at '
            'all; the scan itself is broken',
      );

      final misplaced = <String>[
        for (final line in suggestions)
          if (_positionalPrecedesOption(line)) line,
      ];

      final workspace = Directory.systemTemp.createTempSync(
        'macss_ordering_probe_',
      );
      addTearDown(() {
        if (workspace.existsSync()) workspace.deleteSync(recursive: true);
      });

      final rejectedByTheParser = <String>[];
      for (final suggestion in misplaced) {
        final args = _toArgs(suggestion);
        final stdout = MemorySink();
        final stderr = MemorySink();

        await runMacss(
          args,
          stdout: stdout.sink,
          stderr: stderr.sink,
          workingDirectory: workspace.path,
        );

        final said = await stderr.text();
        if (said.contains('misplaced-option') ||
            said.contains('unexpected-value') ||
            said.contains('repeated-option')) {
          rejectedByTheParser.add('$suggestion  =>  $said');
        }
      }

      expect(
        rejectedByTheParser,
        isEmpty,
        reason:
            'these suggestions are rejected by the real parser before the '
            'command it names ever runs:\n${rejectedByTheParser.join('\n')}',
      );
    },
  );
}

/// `code/cli` is two directories under the repository root.
String _repoRoot() => p.normalize(p.join(Directory.current.path, '..', '..'));

/// Files a person or an agent might actually read and copy a command out of.
///
/// `CHANGELOG.md` is deliberately excluded: its entries are the historical
/// record of what was true in the release they describe, not a live
/// suggestion, and rewriting one to match today's rules would misrepresent
/// what that past release actually accepted.
List<File> _sourcesToScan(String root) {
  final files = <File>[];

  void addDartFilesUnder(String dir) {
    final d = Directory(p.join(root, dir));
    if (!d.existsSync()) return;
    for (final entry in d.listSync(recursive: true)) {
      if (entry is File && entry.path.endsWith('.dart')) files.add(entry);
    }
  }

  addDartFilesUnder(p.join('code', 'cli', 'lib'));

  final skill = File(
    p.join(
      root,
      'code',
      'cli',
      'assets',
      'skills',
      'modules',
      'lifecycle',
      'macss-specification',
      'SKILL.md',
    ),
  );
  if (skill.existsSync()) files.add(skill);

  for (final relative in ['README.md', p.join('docs', 'architecture.md')]) {
    final f = File(p.join(root, relative));
    if (f.existsSync()) files.add(f);
  }

  return files;
}

/// A suggested `macss requisition new/activate ...` line, exactly as
/// written, wherever it appears in the scanned files.
///
/// Scoped to `requisition new`/`requisition activate`: they are the only two
/// routes in this CLI that declare a positional at all
/// (`requisition_builder.dart`'s `new [<slug>]` / `activate [<slug>]`), so
/// they are the only commands an ordering rule like this one can possibly
/// affect.
final _suggestionPattern = RegExp(
  r'macss requisition (?:new|activate)(?: [\w<>\[\]=-]+)*',
);

List<String> _suggestedCommands(String root) {
  final found = <String>{};
  for (final file in _sourcesToScan(root)) {
    for (final match in _suggestionPattern.allMatches(
      file.readAsStringSync(),
    )) {
      found.add(match.group(0)!.trim());
    }
  }
  return found.toList()..sort();
}

/// True when a positional-looking token (`<slug>` or `[<slug>]`) is followed,
/// anywhere later in the line, by a token that looks like an option.
bool _positionalPrecedesOption(String suggestion) {
  final tokens = suggestion.split(' ');
  var sawPositional = false;
  for (final token in tokens) {
    final isPositional = token.contains('<') && token.contains('>');
    final isOption = token.startsWith('-');
    if (isOption && sawPositional) return true;
    if (isPositional) sawPositional = true;
  }
  return false;
}

/// Turns a suggested line into real argv: drops the leading `macss`, and
/// fills the `<slug>`/`[<slug>]` placeholder with a sample value so the
/// router has an actual operand to parse.
List<String> _toArgs(String suggestion) => suggestion
    .split(' ')
    .skip(1)
    .map((t) => t == '<slug>' || t == '[<slug>]' ? 'demo' : t)
    .toList();
