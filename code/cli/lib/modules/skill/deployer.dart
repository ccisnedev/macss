/// Materializes the shipped `SKILL.md` assets into a host's skills directory.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../assets.dart';

/// The prefix MACSS's own skills carry in a host's skills directory.
///
/// It marks what MACSS owns and may therefore retire. Skills without it belong
/// to another tool or to the user, and are never touched.
const macssSkillNamespace = 'macss-';

/// Writes every skill under `assets/skills/` into `<targetDir>/<name>/SKILL.md`,
/// and removes the ones MACSS no longer ships.
///
/// Returns one indented `created` / `updated` / `exists` / `removed` line per
/// skill.
///
/// A skill whose content differs is **refreshed**, not preserved: the target is
/// machine-written output reproducible from the shipped assets, so a stale file
/// left by an older CLI is a defect rather than a user edit. A skill MACSS has
/// dropped is **removed** for the same reason — deployment that can only add
/// leaves frozen copies behind that nothing will ever update again.
List<String> deploySkills({
  required Assets assets,
  required String targetDir,
}) {
  final steps = <String>[];
  final shipped = assets.listDirectory('skills');

  for (final name in shipped) {
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

  steps.addAll(_pruneRetired(targetDir, shipped.toSet()));
  return steps;
}

/// Removes deployed skills in the MACSS namespace that are no longer shipped.
///
/// Scoped by prefix rather than a hand-maintained list of retirements: the
/// `macss-` namespace is ours, so anything under it we do not ship is ours to
/// remove. That makes it self-maintaining — a skill renamed or dropped in a
/// future release is cleaned without anyone remembering to list it.
///
/// Everything else in the directory is left alone: another tool's skills, and
/// anything the user wrote.
List<String> _pruneRetired(String targetDir, Set<String> shipped) {
  final dir = Directory(targetDir);
  if (!dir.existsSync()) return const [];

  final retired = <String>[];
  for (final entry in dir.listSync().whereType<Directory>()) {
    final name = p.basename(entry.path);
    if (!name.startsWith(macssSkillNamespace)) continue;
    if (shipped.contains(name)) continue;
    entry.deleteSync(recursive: true);
    retired.add(name);
  }

  retired.sort();
  return retired.map((name) => '  removed  $name (no longer shipped)').toList();
}
