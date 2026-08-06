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
  final missing = entries.where((e) => !content.contains(e)).toList();
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

  final lines = gitignore.readAsLinesSync().map((l) => l.trim());
  return entries.where(lines.contains).toList();
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
  final kept = <String>[];
  var removed = 0;

  for (var i = 0; i < lines.length; i++) {
    if (entries.contains(lines[i].trim())) {
      removed++;
      continue;
    }
    // A header whose every entry has just been retired describes nothing.
    if (lines[i].trim() == _header && _headerIsNowEmpty(lines, i, entries)) {
      continue;
    }
    kept.add(lines[i]);
  }

  if (removed == 0) return null;

  while (kept.isNotEmpty && kept.last.trim().isEmpty) {
    kept.removeLast();
  }
  gitignore.writeAsStringSync('${kept.join('\n')}\n');
  return 'Retired ${removed == 1 ? 'an entry' : '$removed entries'} '
      'from .gitignore';
}

/// Whether every line under the header at [index], up to the next blank line or
/// comment, is being retired.
bool _headerIsNowEmpty(List<String> lines, int index, List<String> entries) {
  for (var i = index + 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty || line.startsWith('#')) return true;
    if (!entries.contains(line)) return false;
  }
  return true;
}
