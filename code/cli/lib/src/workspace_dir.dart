/// The MACSS local workspace, and the one place that brings it into existence.
///
/// `.macss/` holds what the tool writes for itself — the active-requisition
/// pointer, and since ADR 0007 the plan files. None of that belongs in version
/// control; the project's configuration, which lives in the same directory,
/// does.
///
/// **The rule lives inside the directory it governs.** Not in the project's root
/// `.gitignore`, for three reasons: it works where there is no repository, it
/// does not argue with whatever the root already says, and deleting `.macss/`
/// takes the rule with it instead of leaving an orphan line pointing at nothing.
///
/// It is an **allowlist** — ignore everything, name the exceptions — because of
/// how the two designs fail. A denylist forgets in silence: anything MACSS
/// invents here later is committed until somebody remembers to add it, and
/// remembering is not a control. An allowlist forgets in the open: somebody
/// clones, a file is missing, and it is noticed.
///
/// `!.gitignore` is not decoration. Without it the file that makes every other
/// rule work is itself ignored, never committed, and nobody who clones the
/// project ever receives it.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// The directory name, relative to a project root.
const workspaceDirName = '.macss';

/// What the workspace's own `.gitignore` says.
const workspaceGitignore = '''
# MACSS — this workspace ignores itself.
# Everything here is machine-written and reproducible, except what is named
# below: those are decisions a human made, and they travel with the repository.
*
!.gitignore
!config.yaml
''';

/// Ensures `<root>/.macss/` exists and carries its own ignore rule.
///
/// Returns the workspace directory. Idempotent, and it never overwrites a rule
/// that is already there — a project that has adjusted its own exceptions keeps
/// them.
///
/// Every path that creates the workspace goes through here. When only
/// `requisition new` knew about the rule, `--plan` in a project that had never
/// opened a requisition created `.macss/` with nothing ignoring it, which is the
/// defect this exists to prevent.
Directory ensureWorkspace(String root) {
  final dir = Directory(p.join(root, workspaceDirName));
  if (!dir.existsSync()) dir.createSync(recursive: true);

  final rule = File(p.join(dir.path, '.gitignore'));
  if (!rule.existsSync()) rule.writeAsStringSync(workspaceGitignore);

  return dir;
}
