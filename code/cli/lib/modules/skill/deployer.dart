/// Materializes the shipped `SKILL.md` assets into a target skills directory.
///
/// Shared by `macss skill deploy` and `macss create`, so a freshly scaffolded
/// project arrives with its skills already in place and both paths cannot drift.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../assets.dart';

/// Writes every skill under `assets/skills/` into `<targetDir>/<name>/SKILL.md`.
///
/// Returns one `created` / `updated` / `exists` line per skill, using [display]
/// as the directory label in those lines.
///
/// A skill whose content differs is **refreshed**, not preserved: the target is
/// machine-written output reproducible from the shipped assets, so a stale file
/// left by an older CLI is a defect rather than a user edit.
List<String> deploySkills({
  required Assets assets,
  required String targetDir,
  required String display,
}) {
  final steps = <String>[];

  for (final name in assets.listDirectory('skills')) {
    final content = assets.loadString('skills/$name/SKILL.md');
    final file = File(p.join(targetDir, name, 'SKILL.md'));
    final label = p.posix.join(display, name, 'SKILL.md');

    if (!file.existsSync()) {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(content);
      steps.add('created  $label');
    } else if (file.readAsStringSync() != content) {
      file.writeAsStringSync(content);
      steps.add('updated  $label');
    } else {
      steps.add('exists   $label');
    }
  }

  return steps;
}
