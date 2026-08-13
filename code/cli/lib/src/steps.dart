/// Steps shared by more than one command.
///
/// Writing a file that must not be overwritten, and keeping the workspace
/// git-ignored, are things half the CLI does. Each was written out per command
/// before there were steps, which is why the same `existsSync()` decision
/// appeared twice in the same file — once for the preview and once for the
/// work.
library;

import 'dart:io';

import 'package:modular_cli_sdk/modular_cli_sdk.dart';

import 'gitignore.dart';

/// Writes a file, or keeps the one already there.
///
/// [contents] is settled by whoever builds the step. A step that resolved a
/// template inside `perform` would be deriving a second time what the preview
/// already described, and the two would be free to differ.
class WriteFile implements Step {
  WriteFile({required this.path, required this.contents, String? shownAs})
    : shownAs = shownAs ?? path;

  /// Where it goes on disk.
  final String path;

  final String contents;

  /// How the path is named in a plan. Commands that work inside a project show
  /// a path relative to it: the reader knows where they are, and the absolute
  /// path is noise that differs on every machine.
  final String shownAs;

  bool get _exists => File(path).existsSync();

  @override
  Preview preview() => _exists
      ? Preview(verb: 'keep', target: shownAs, detail: 'already exists')
      : Preview(verb: 'create', target: shownAs);

  @override
  Future<Outcome> perform(StepContext context) async {
    if (_exists) return Outcome(verb: 'keep', target: shownAs);

    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
    return Outcome(verb: 'create', target: shownAs);
  }
}

/// Keeps the MACSS workspace out of version control.
///
/// Runs before anything is written into the workspace, so a project never has
/// a committed `.macss/` even briefly.
class EnsureWorkspaceGitignored implements Step {
  EnsureWorkspaceGitignored(this.root);

  final String root;

  @override
  Preview preview() {
    final missing = missingGitignoreEntriesIn(root);
    return missing.isEmpty
        ? Preview(verb: 'exists', target: '.gitignore', detail: 'MACSS entries')
        : Preview(
            verb: 'ensure',
            target: '.gitignore',
            detail: 'adds ${missing.join(', ')}',
          );
  }

  @override
  Future<Outcome> perform(StepContext context) async {
    final changed = ensureGitignoreEntries(root);
    return changed == null
        ? Outcome(verb: 'exists', target: '.gitignore')
        : Outcome(
            verb: 'ensure',
            target: '.gitignore',
            values: {'summary': changed},
          );
  }
}
