/// Materializes the shipped `SKILL.md` assets into a host's skills directory.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../assets.dart';

/// Writes every skill under `assets/skills/` into `<targetDir>/<name>/SKILL.md`.
///
/// Returns one indented `created` / `updated` / `exists` line per skill.
///
/// A skill whose content differs is **refreshed**, not preserved: the target is
/// machine-written output reproducible from the shipped assets, so a stale file
/// left by an older CLI is a defect rather than a user edit.
List<String> deploySkills({
  required Assets assets,
  required String targetDir,
}) {
  final steps = <String>[];

  for (final name in assets.listDirectory('skills')) {
    final content = assets.loadString('skills/$name/SKILL.md');
    final file = File(p.join(targetDir, name, 'SKILL.md'));

    if (!file.existsSync()) {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(content);
      steps.add('  created  $name');
    } else if (file.readAsStringSync() != content) {
      file.writeAsStringSync(content);
      steps.add('  updated  $name');
    } else {
      steps.add('  exists   $name');
    }
  }

  return steps;
}
