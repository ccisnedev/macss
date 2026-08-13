/// Shared `.gitignore` management for the MACSS local workspace.
///
/// Requisitions live under `docs/requisitions/` but are a **local authoring
/// workspace** — the durable artifacts are the published GitHub issues (plus
/// the code + tests that carry the spec→issue→test spine). Ignoring them keeps
/// the repo clean and removes the "requisitions accumulation" problem entirely,
/// while the `<YYYYMMDD>-<slug>` naming still sorts them chronologically on disk.
library;

import 'dart:io';

/// The `.gitignore` entries MACSS manages (idempotently).
///
/// `docs/requisitions/` is the authoring workspace described above: machine
/// written, reproducible, and outside `.macss/`, so the root is where it has to
/// be named.
///
/// The implementation cleanroom is deliberately absent: it belongs to the
/// inquiry FSM, which manages its own entries. So are the skills — they are
/// installed once per machine under the user's home, not per repository.
const macssGitignoreEntries = <String>[
  'docs/requisitions/',
];

/// Entries MACSS used to manage and now retires from a project's root.
///
/// `.macss/` was here, and it had to go: while the root excluded the directory,
/// git never descended into it, so the workspace's own `.gitignore` was dead
/// letter and `config.yaml` could not be versioned. Retiring it is what lets
/// the workspace govern itself.
///
/// Retiring is safe for the same reason `skill deploy` prunes its own
/// namespace: an entry under the MACSS header is machine-written output, not a
/// user edit. Nothing outside that header is ever touched.
const macssRetiredGitignoreEntries = <String>[
  '.macss/',
];

const _header = '# MACSS — local workspace (git-ignored)';

/// Which of [entries] a project's root `.gitignore` does not carry yet.
///
/// The counterpart of [retiredGitignoreEntriesIn], and asked for the same
/// reason: a step has to be able to say what it would add without adding it.
/// [ensureGitignoreEntries] answers from here too, so the two are one rule
/// consulted twice rather than two free to disagree.
List<String> missingGitignoreEntriesIn(
  String root, {
  List<String> entries = macssGitignoreEntries,
}) {
  final gitignore = File('$root/.gitignore');
  if (!gitignore.existsSync()) return List.of(entries);

  final content = gitignore.readAsStringSync();
  return entries.where((e) => !content.contains(e)).toList();
}

/// Ensures [entries] exist in `<root>/.gitignore` under the MACSS header.
/// Idempotent — only missing entries are appended. Returns a one-line status
/// when the file changed, otherwise `null`.
String? ensureGitignoreEntries(
  String root, {
  List<String> entries = macssGitignoreEntries,
}) {
  final gitignore = File('$root/.gitignore');

  if (!gitignore.existsSync()) {
    gitignore.writeAsStringSync('$_header\n${entries.join('\n')}\n');
    return 'Created .gitignore with MACSS entries';
  }

  var content = gitignore.readAsStringSync();
  final missing = missingGitignoreEntriesIn(root, entries: entries);
  if (missing.isEmpty) return null;

  if (!content.endsWith('\n')) content = '$content\n';
  content = '$content$_header\n${missing.join('\n')}\n';
  gitignore.writeAsStringSync(content);
  return 'Added MACSS entries to .gitignore';
}

/// Which of [entries] a project's root `.gitignore` still carries.
///
/// Asked before removing anything, so a caller can put the retirement in a plan
/// (ADR 0007) rather than discovering it as a side effect of applying.
List<String> retiredGitignoreEntriesIn(
  String root, {
  List<String> entries = macssRetiredGitignoreEntries,
}) {
  final gitignore = File('$root/.gitignore');
  if (!gitignore.existsSync()) return const [];

  final lines = gitignore.readAsLinesSync();
  final present = {
    for (final block in _managedBlocks(lines))
      for (final i in block.entries) lines[i].trim(),
  };
  return entries.where(present.contains).toList();
}

/// Removes [entries] from `<root>/.gitignore`, and nothing else.
///
/// Only exact lines are removed, so a rule that merely mentions the same text —
/// `!.macss/keep` — is left alone. Everything the project wrote itself survives
/// byte for byte, which is the whole licence for touching the file at all: MACSS
/// retires what MACSS wrote, on the same argument by which `skill deploy` prunes
/// the `macss-` namespace.
///
/// A MACSS header left with no entries under it goes too, rather than sitting
/// there labelling nothing.
String? removeGitignoreEntries(
  String root, {
  List<String> entries = macssRetiredGitignoreEntries,
}) {
  final gitignore = File('$root/.gitignore');
  if (!gitignore.existsSync()) return null;

  final lines = gitignore.readAsLinesSync();
  final blocks = _managedBlocks(lines);

  final doomed = <int>{};
  for (final block in blocks) {
    final retiring =
        block.entries.where((i) => entries.contains(lines[i].trim()));
    doomed.addAll(retiring);
    // A header left describing nothing goes with its entries.
    if (retiring.length == block.entries.length) doomed.add(block.header);
  }

  if (doomed.isEmpty) return null;

  final kept = [
    for (var i = 0; i < lines.length; i++)
      if (!doomed.contains(i)) lines[i],
  ];
  while (kept.isNotEmpty && kept.last.trim().isEmpty) {
    kept.removeLast();
  }
  gitignore.writeAsStringSync('${kept.join('\n')}\n');

  final count = doomed.where((i) => lines[i].trim() != _header).length;
  return 'Retired ${count == 1 ? 'an entry' : '$count entries'} '
      'from .gitignore';
}

/// One MACSS-managed block: the header line, and the entry lines under it.
class _ManagedBlock {
  final int header;
  final List<int> entries;
  const _ManagedBlock(this.header, this.entries);
}

/// Every MACSS-managed block in [lines].
///
/// A block runs from the MACSS header to the first blank line or the next
/// comment. **That boundary is the entire licence for touching this file.** The
/// same text written by the project, in the project's own section, is a decision
/// a human made — and ADR 0004's "adopt never deletes" exists to protect exactly
/// that. An earlier version of this matched the line anywhere in the file, which
/// deleted the project's copy along with ours.
List<_ManagedBlock> _managedBlocks(List<String> lines) {
  final blocks = <_ManagedBlock>[];
  var header = -1;
  var entries = <int>[];

  void close() {
    if (header >= 0) blocks.add(_ManagedBlock(header, entries));
    header = -1;
    entries = <int>[];
  }

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();

    if (line == _header) {
      close();
      header = i;
      continue;
    }
    if (header < 0) continue;
    if (line.isEmpty || line.startsWith('#')) {
      close();
      continue;
    }
    entries.add(i);
  }
  close();

  return blocks;
}
