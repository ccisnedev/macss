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
/// Both are machine-written and reproducible from the CLI, so neither belongs in
/// version control:
/// - `.macss/` holds local state, such as the active-requisition pointer.
/// - `docs/requisitions/` is the authoring workspace described above.
///
/// The implementation cleanroom is deliberately absent: it belongs to the
/// inquiry FSM, which manages its own entries. So are the skills — they are
/// installed once per machine under the user's home, not per repository.
const macssGitignoreEntries = <String>[
  '.macss/',
  'docs/requisitions/',
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
