import 'dart:io';

import 'package:path/path.dart' as p;

/// One command token: a bare word, a `<placeholder>` (optionally with
/// `|`-separated alternatives), an optional `[<placeholder>]`, a
/// `--long-option[=value]`, or a `-x` short option.
const _tokenPattern =
    r'(?:[a-zA-Z][\w-]*'
    r'|<[^<>\s]+(?:\|[^<>\s]+)*>'
    r'|\[<[^<>\s]+(?:\|[^<>\s]+)*>\]'
    r'|--[\w-]+(?:=\S+)?'
    r'|-[a-zA-Z])';

/// A `macss` invocation followed by one or more tokens, joined only by
/// horizontal whitespace (`[ \t]`, never `\n`). Restricting the separator to
/// non-newline whitespace is deliberate: with plain `\s+` a match can jump
/// across a line break and stitch unrelated lines together (three separate
/// example lines merged into one, or a word-wrapped sentence mistaken for an
/// invocation). Anchoring to a single line makes that structurally
/// impossible.
final RegExp _commandPattern = RegExp('macss(?:[ \\t]+$_tokenPattern)+');

/// A fenced code block's body, across every common language tag (or none).
final RegExp _fencedBlock = RegExp(r'```[a-zA-Z0-9_-]*\n([\s\S]*?)```');

/// An inline code span, e.g. `` `macss requisition new --apply <slug>` ``.
final RegExp _inlineCode = RegExp(r'`([^`\n]+)`');

/// A Dart string literal: triple-quoted (raw or not), or single-line
/// single/double-quoted (which cannot themselves contain a literal newline).
final RegExp _dartStringLiteral = RegExp(
  r"r?'''[\s\S]*?'''"
  r'|r?"""[\s\S]*?"""'
  r"|r?'(?:[^'\\\n]|\\.)*'"
  r'|r?"(?:[^"\\\n]|\\.)*"',
);

Iterable<String> _matches(String text) =>
    _commandPattern.allMatches(text).map((m) => m.group(0)!);

/// Extracts candidate `macss ...` invocations from prose/markdown [text],
/// restricted to fenced code blocks and inline code spans. Anything written
/// as plain narrative — including a sentence that merely starts with
/// "macss" as its subject — is excluded by construction, because it is
/// never wrapped in backticks.
List<String> extractCommandsFromProse(String text) {
  final found = <String>[];
  for (final block in _fencedBlock.allMatches(text)) {
    found.addAll(_matches(block.group(1) ?? ''));
  }
  for (final span in _inlineCode.allMatches(text)) {
    found.addAll(_matches(span.group(1) ?? ''));
  }
  return found;
}

/// Extracts candidate `macss ...` invocations from Dart [source], restricted
/// to the contents of string literals (hint strings, usage strings, error
/// messages) — never identifiers, comments, or doc-comment prose.
List<String> extractCommandsFromDart(String source) {
  final found = <String>[];
  for (final literal in _dartStringLiteral.allMatches(source)) {
    found.addAll(_matches(literal.group(0) ?? ''));
  }
  return found;
}

/// One extracted command together with the file it came from, so a failure
/// can point back at its source.
class ExtractedCommand {
  ExtractedCommand(this.relativePath, this.raw);

  final String relativePath;
  final String raw;

  @override
  String toString() => '$relativePath :: $raw';
}

/// Every file this repository ships that could put a `macss ...` example in
/// front of a person or an agent: the CLI's own source, every asset it
/// installs (skills, templates, vocabularies), the top-level README, and the
/// documentation tree.
List<File> sourceFilesToScan(String repoRoot) {
  final files = <File>[];

  void addFilesUnder(String relativeDir, {bool Function(File)? include}) {
    final dir = Directory(p.join(repoRoot, relativeDir));
    if (!dir.existsSync()) return;
    for (final entry in dir.listSync(recursive: true)) {
      if (entry is! File) continue;
      if (include != null && !include(entry)) continue;
      files.add(entry);
    }
  }

  addFilesUnder(
    p.join('code', 'cli', 'lib'),
    include: (f) => f.path.endsWith('.dart'),
  );
  addFilesUnder(p.join('code', 'cli', 'assets'));
  addFilesUnder('docs');

  final readme = File(p.join(repoRoot, 'README.md'));
  if (readme.existsSync()) files.add(readme);

  return files;
}

/// Module nouns that `docs/` and `README.md` name in running prose
/// (`macss issue`, `macss agent`, ...) for modules that are planned,
/// superseded or explicitly nonexistent. A bare `macss <word>` mention is
/// skipped only when `<word>` is in this list; every other bare mention,
/// such as `macss doctor` or `macss version` in the project-base template,
/// is a live suggestion and goes through the router like any other.
const Set<String> _plannedOrAbsentModuleNouns = {
  'agent',
  'ai',
  'app',
  'db',
  'deploy',
  'diagnosis',
  'fsm',
  'implementation',
  'issue',
  'plan',
  'pr',
  'review',
};

bool _isProseModuleNoun(String command) {
  final tokens = command.trim().split(RegExp('[ \t]+'));
  return tokens.length == 2 && _plannedOrAbsentModuleNouns.contains(tokens[1]);
}

/// Extracted text that is a historical, superseded, or explicitly
/// not-yet-built citation rather than a live suggestion, each excluded for
/// a documented reason grounded in what its own source says — never because
/// it was merely inconvenient:
///
/// - Every root-level `macss create ...` form: the positional-argument
///   `create` command ADR 0002 quotes was deprecated in 0.3.0 and removed in
///   0.5.0 (ADR 0004's own status note, `docs/roadmap.md:515`); today's
///   equivalent is `macss project create`, a distinct command already
///   covered on its own.
/// - `macss issue publish`: ADR 0004's status note says outright it "no
///   longer exists"; `docs/roadmap.md` confirms "There is no `macss issue`
///   module."
/// - `macss api graphql check` / `macss api graphql schema` / `macss api
///   compile`: `docs/architecture.md`'s "Subsurface Commands" section lists
///   these under "Preferred shape" for a surface it calls a "planned
///   example", and only `graphql compile` is implemented
///   (`lib/modules/api/api_builder.dart` registers no other `api` route).
/// - `macss db migrate --apply`: `docs/architecture.md` annotates this
///   itself — "*(planned; the `db` module does not exist yet)*".
/// - The CLI's abstract grammar shape, spelled with placeholder category
///   names rather than a concrete runnable example — README.md's
///   `macss <module> <surface> <action>` and architecture.md's
///   `macss <module?> <surface?> <action>`.
/// - `macss api graphql` (bare, no leaf): `docs/architecture.md` uses it as
///   a noun phrase naming the module+surface pair ("this work belongs under
///   `macss api graphql`"), the same way bare `macss project` names a
///   module; every actual invocation of this surface already appears with
///   its leaf action (`... compile`) and is covered on its own.
/// - `macss guide deploy` (with or without `--host claude`):
///   `docs/macss_skills.md` introduces `macss-guide` itself as "(nombre
///   provisional)" ["provisional name"] with the command's own placement
///   marked "Pendiente de decisión" ["pending decision"] — proposed, not
///   shipped. No `guide` module exists in `lib/modules`.
const _knownNonSuggestions = <String>{
  'macss issue publish',
  'macss api graphql check',
  'macss api graphql schema',
  'macss api compile',
  'macss api graphql',
  'macss db migrate --apply',
  'macss <module?> <surface?> <action>',
  'macss <module> <surface> <action>',
  'macss guide deploy',
  'macss guide deploy --host claude',
};

bool _isRootLevelCreate(String command) {
  final tokens = command.split(RegExp('[ \\t]+'));
  return tokens.length >= 2 && tokens[0] == 'macss' && tokens[1] == 'create';
}

/// All commands this repository suggests, deduplicated by their exact text
/// together with every file that suggests them (so a report can name every
/// offending source), with single bare module/product names and the small,
/// documented set of historical/planned/grammar-shape citations above
/// removed.
List<ExtractedCommand> collectSuggestedCommands(String repoRoot) {
  final found = <ExtractedCommand>[];
  for (final file in sourceFilesToScan(repoRoot)) {
    final text = file.readAsStringSync();
    final relative = p.relative(file.path, from: repoRoot);
    final raw = file.path.endsWith('.dart')
        ? extractCommandsFromDart(text)
        : extractCommandsFromProse(text);
    for (final command in raw) {
      if (_isProseModuleNoun(command)) continue;
      if (_knownNonSuggestions.contains(command)) continue;
      if (_isRootLevelCreate(command)) continue;
      found.add(ExtractedCommand(relative, command));
    }
  }
  return found;
}

/// Sample values for recognized placeholder names, chosen only to be
/// syntactically acceptable to the router — a semantically wrong value
/// (a slug for a project that does not exist) only ever produces a
/// business-logic error, never one of the five structural rejections this
/// suite watches for.
const _placeholderSamples = <String, String>{
  'slug': 'demo',
  'name': 'demo',
  'path': '.',
  'dir': '.',
  'lang': 'en',
  'host': 'claude-code',
  'hosts': 'claude-code',
  'assistant': 'claude-code',
};

final RegExp _placeholderName = RegExp(r'<([^<>]+)>');

String _sampleFor(String placeholderName) {
  if (placeholderName.contains('|')) return placeholderName.split('|').first;
  return _placeholderSamples[placeholderName.toLowerCase()] ?? 'sample';
}

/// Fills every `<placeholder>` in [token] with a sample value, and unwraps an
/// optional `[<placeholder>]` to the bare filled value — `[<slug>]` becomes
/// `demo`, the same as `<slug>` would, since once a value is supplied the
/// brackets no longer mean anything to the router.
String _fillToken(String token) {
  var text = token;
  if (text.startsWith('[') && text.endsWith(']')) {
    text = text.substring(1, text.length - 1);
  }
  return text.replaceAllMapped(
    _placeholderName,
    (m) => _sampleFor(m.group(1)!),
  );
}

/// Turns a suggested `macss ...` line into real argv: drops the leading
/// `macss`, splits on any run of horizontal whitespace (some sources pad
/// columns with more than one space or a tab), and fills in every
/// placeholder.
List<String> toArgs(String suggestion) => suggestion
    .split(RegExp('[ \\t]+'))
    .skip(1)
    .map(_fillToken)
    .toList(growable: false);
