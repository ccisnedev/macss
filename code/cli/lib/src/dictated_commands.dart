/// Judges the invocations this CLI puts in front of somebody, by asking the CLI.
///
/// The defect this exists for is that the messages **read** correctly.
/// ``macss requisition new <slug>`` is a sentence anybody would approve in
/// review, and
/// the binary refuses it: ADR 0007 made the choice between planning and
/// applying mandatory, and the message was written before that and never
/// re-read. Reading is what failed, three separate times — so nothing here
/// reads. Every judgement is asked of the catalogue the CLI publishes.
///
/// Nothing is registered, either. A registry of dictated commands would be a
/// second list to keep in step with the messages, and would leave a raw string
/// added tomorrow unguarded — which is the one thing the requirement asks to
/// prevent. This reads what is actually in the source and in the shipped
/// skills, so a new message is covered because it exists, not because somebody
/// remembered it.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// One invocation of this CLI, as it appears in something a reader will see.
class DictatedCommand {
  /// Repository-relative file, for a report that can be acted on.
  final String file;
  final int line;

  /// The invocation as written, placeholders and all.
  final String invocation;

  const DictatedCommand({
    required this.file,
    required this.line,
    required this.invocation,
  });

  @override
  String toString() => '$file:$line  $invocation';
}

/// What the CLI answered about a dictated invocation.
class DictatedVerdict {
  final DictatedCommand command;

  /// Null when the CLI accepts it; otherwise why it would not.
  final String? rejection;

  const DictatedVerdict(this.command, this.rejection);

  bool get accepted => rejection == null;

  @override
  String toString() => '${command.file}:${command.line}\n'
      '  dictates  ${command.invocation}\n'
      '  rejected  $rejection';
}

// ─── Extraction ─────────────────────────────────────────────────────────────

/// Anything reading as an invocation of this CLI: `macss` followed by words and
/// options, up to whatever closes it.
///
/// Deliberately generous. A false positive is a line somebody has to look at; a
/// false negative is the defect surviving, which is what happened three times.
final _invocation = RegExp(r'macss((?:\s+(?:<[a-z|]+>|--?[a-z][\w-]*(?:=\S+)?|'
    r'[a-z][\w./|-]*))+)');

/// True for a line that only a maintainer reads — doc comments and `//` notes.
///
/// A dictated command inside a doc comment is documentation of the command, not
/// an instruction to run one; judging it would report the library header of
/// every file in this package.
bool _isComment(String line) {
  final t = line.trimLeft();
  return t.startsWith('///') || t.startsWith('//') || t.startsWith('*');
}

/// Every invocation appearing in [file]'s user-facing text.
List<DictatedCommand> dictatedIn(File file, {required String relativeTo}) {
  final rel = p.posix.joinAll(p.split(p.relative(file.path, from: relativeTo)));
  final isDart = file.path.endsWith('.dart');
  final found = <DictatedCommand>[];

  final lines = file.readAsLinesSync();
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (isDart && _isComment(line)) continue;

    for (final m in _invocation.allMatches(line)) {
      // Trailing punctuation belongs to the sentence, not the command.
      final invocation = 'macss${m.group(1)!}'.replaceAll(RegExp(r'[.,:;]$'), '');
      found.add(
        DictatedCommand(file: rel, line: i + 1, invocation: invocation),
      );
    }
  }
  return found;
}

// ─── The catalogue the judgement is asked of ────────────────────────────────

/// One route as the CLI publishes it in `help --json`.
///
/// Public because the judgement is a two-step the caller drives: fetch what the
/// CLI says about itself once, then judge every invocation against it.
class CliRoute {
  final String route;
  final Set<String> declared;
  final Set<String> requiredOptions;

  /// How many bare arguments the route takes after its name.
  final int positionals;

  /// Options that carry a value, so the token after them is that value and not
  /// an argument. Without this, `--lang en` reads as a stray word.
  final Set<String> valueOptions;

  /// Whether the command changes anything — derived, never asserted. A command
  /// declares `--plan` and `--apply` if and only if it changes something
  /// (ADR 0007), so the catalogue already answers this and a hand-kept list of
  /// "the mutating commands" would be a second answer free to disagree.
  bool get mutating => declared.contains('plan');

  const CliRoute(
    this.route,
    this.declared,
    this.requiredOptions,
    this.positionals,
    this.valueOptions,
  );
}

/// Parses the catalogue the CLI emits for `help --json`.
List<CliRoute> parseCatalog(String helpJson) {
  final doc = jsonDecode(helpJson) as Map<String, dynamic>;
  return [
    for (final c in (doc['commands'] as List).cast<Map<String, dynamic>>())
      CliRoute(
        c['route'] as String,
        {
          for (final param in (c['params'] as List).cast<Map<String, dynamic>>())
            param['name'] as String,
        },
        {
          for (final param in (c['params'] as List).cast<Map<String, dynamic>>())
            if (param['required'] == true && param['kind'] == 'option')
              param['name'] as String,
        },
        (c['params'] as List)
            .cast<Map<String, dynamic>>()
            .where((param) => param['kind'] == 'positional')
            .length,
        {
          for (final param in (c['params'] as List).cast<Map<String, dynamic>>())
            if (param['kind'] == 'option') param['name'] as String,
        },
      ),
  ];
}

// ─── Judgement ──────────────────────────────────────────────────────────────

/// Asks the catalogue whether [command] is something the CLI would take.
///
/// Not whether running it would succeed — that depends on the state of a
/// project. Whether the CLI takes it as a valid thing to ask: the route exists,
/// every option is declared, nothing required is absent, and a command that
/// changes something has been told which of planning or applying is meant.
DictatedVerdict judge(DictatedCommand command, List<CliRoute> catalog) {
  final tokens = command.invocation.split(RegExp(r'\s+')).skip(1).toList();

  // The route is named by the bare words before any option, so it can be found
  // before anything is known about which options carry values.
  final leading = tokens.takeWhile((t) => !t.startsWith('-')).toList();

  // The longest route whose words this invocation opens with. `requisition new`
  // must win over a hypothetical `requisition`, or every subcommand would be
  // judged against its parent's contract.
  CliRoute? matched;
  var matchedLength = 0;
  for (final candidate in catalog) {
    // A route's own positional (`requisition new <slug>`) is supplied by the
    // reader, so it is not part of what identifies the route.
    final base =
        candidate.route.split(' ').where((w) => !w.startsWith('<')).toList();
    if (base.isEmpty || base.length > leading.length) continue;
    if (!_startsWith(leading, base)) continue;
    if (base.length > matchedLength) {
      matched = candidate;
      matchedLength = base.length;
    }
  }

  if (matched == null) {
    return DictatedVerdict(command, 'no such command in this CLI');
  }

  // Now the route is known, so the tokens can be read the way the CLI reads
  // them: an option that carries a value swallows the token after it, and what
  // is left over is a bare argument.
  final flags = <String>{};
  var arguments = 0;
  for (var i = matchedLength; i < tokens.length; i++) {
    final token = tokens[i];
    if (!token.startsWith('-')) {
      arguments++;
      continue;
    }
    final name = token.replaceFirst(RegExp('^--?'), '').split('=').first;
    flags.add(name);
    // `--json`, `--quiet` and `--help` are global flags and carry no value.
    if (matched.valueOptions.contains(name) && !token.contains('=')) {
      i++; // the next token is this option's value, not an argument
    }
  }

  final undeclared = flags.difference(matched.declared)
    ..removeAll(_globalOptions);
  if (undeclared.isNotEmpty) {
    return DictatedVerdict(
      command,
      '"${matched.route}" declares no ${undeclared.map((f) => '--$f').join(', ')}',
    );
  }

  // A bare word the route does not take. `macss specification new <slug>` reads
  // perfectly and is refused: that command takes `--slug`, and the loose word
  // is an argument it never declared.
  if (arguments > matched.positionals) {
    return DictatedVerdict(
      command,
      matched.positionals == 0
          ? '"${matched.route}" takes no argument after the command'
          : '"${matched.route}" takes ${matched.positionals} argument(s), '
              'not $arguments',
    );
  }

  if (matched.mutating && flags.intersection(const {'plan', 'apply'}).isEmpty) {
    return DictatedVerdict(
      command,
      '"${matched.route}" changes things and refuses to choose: '
          'it needs --plan or --apply',
    );
  }

  if (!matched.mutating &&
      flags.intersection(const {'plan', 'apply'}).isNotEmpty) {
    return DictatedVerdict(
      command,
      '"${matched.route}" only reports, and rejects --plan and --apply',
    );
  }

  final missing = matched.requiredOptions.difference(flags);
  if (missing.isNotEmpty) {
    return DictatedVerdict(
      command,
      '"${matched.route}" requires ${missing.map((f) => '--$f').join(', ')}',
    );
  }

  return DictatedVerdict(command, null);
}

/// Accepted on every route, so their absence from a route's parameters is not a
/// defect in the message.
const _globalOptions = {'json', 'quiet', 'help'};

bool _startsWith(List<String> words, List<String> prefix) {
  for (var i = 0; i < prefix.length; i++) {
    if (words[i] != prefix[i]) return false;
  }
  return true;
}
