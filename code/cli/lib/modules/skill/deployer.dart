/// Materializes the shipped `SKILL.md` assets into a host's skills directory,
/// as one step per skill.
///
/// This used to be a single function with a `dryRun` flag, and the comment
/// above it argued that one function deciding and reporting was what kept
/// `--plan` and `--apply` from describing different things. The argument was
/// right about the goal and wrong about the mechanism: a flag threaded through
/// the work is only ever as faithful as whoever last edited the branches, and
/// nothing checked it. Each skill is now a [Step] that says what it would do
/// and then does it, and the executor compares the two.
///
/// The other thing that changed: the asset's contents are read when the step is
/// **built**, not again inside `perform`. Deriving the same answer twice is how
/// a preview comes to describe a different change from the one that happens.
library;

import 'dart:io';

import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../assets.dart';

/// The prefix MACSS's own skills carry in a host's skills directory.
///
/// It marks what MACSS owns and may therefore retire. Skills without it belong
/// to another tool or to the user, and are never touched.
const macssSkillNamespace = 'macss-';

/// Every step deploying the shipped skills into [targetDir] would take.
///
/// A skill whose content differs is **refreshed**, not preserved: the target is
/// machine-written output reproducible from the shipped assets, so a stale file
/// left by an older CLI is a defect rather than a user edit. A skill MACSS has
/// dropped is **removed** for the same reason — deployment that can only add
/// leaves frozen copies behind that nothing will ever update again.
List<Step> deploySkillSteps({
  required Assets assets,
  required String targetDir,
}) {
  final shipped = assets.listDirectory('skills');
  return [
    for (final name in shipped)
      DeploySkill(
        name: name,
        contents: assets.loadString('skills/$name/SKILL.md'),
        targetDir: targetDir,
      ),
    ..._retirementSteps(targetDir, shipped.toSet()),
  ];
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
List<Step> _retirementSteps(String targetDir, Set<String> shipped) {
  final dir = Directory(targetDir);
  if (!dir.existsSync()) return const [];

  final retired =
      <String>[
        for (final entry in dir.listSync().whereType<Directory>())
          if (p.basename(entry.path).startsWith(macssSkillNamespace) &&
              !shipped.contains(p.basename(entry.path)))
            p.basename(entry.path),
      ]..sort();

  return [
    for (final name in retired)
      RemoveSkill(
        directory: p.join(targetDir, name),
        reason: 'no longer shipped',
      ),
  ];
}

/// Writes one skill, refreshes it when it has drifted, or leaves it alone.
class DeploySkill implements Step {
  DeploySkill({
    required this.name,
    required this.contents,
    required this.targetDir,
  });

  final String name;

  /// Read from the assets when this step was built, and not again.
  final String contents;

  final String targetDir;

  /// The skill's own directory — the target, because the same skill name is
  /// deployed to more than one host in a single run, and a plan whose lines
  /// cannot be told apart is not a plan.
  String get directory => p.join(targetDir, name);

  File get _file => File(p.join(directory, 'SKILL.md'));

  /// What deploying this skill would do, decided by looking.
  ///
  /// One function, called by both [preview] and [perform], so the two cannot
  /// disagree about the *rule*. They can still disagree about the *world* — a
  /// file that appears between the two calls — and noticing that is exactly
  /// what the executor is for.
  String _verdict() {
    final file = _file;
    if (!file.existsSync()) return 'create';
    if (file.readAsStringSync() != contents) return 'update';
    return 'exists';
  }

  @override
  Preview preview() => Preview(verb: _verdict(), target: directory);

  @override
  Future<Outcome> perform(StepContext context) async {
    final verdict = _verdict();
    if (verdict != 'exists') {
      _file.parent.createSync(recursive: true);
      _file.writeAsStringSync(contents);
    }
    return Outcome(verb: verdict, target: directory);
  }
}

/// Removes one deployed skill, or reports that there was nothing there.
class RemoveSkill implements Step {
  RemoveSkill({required this.directory, this.reason});

  final String directory;

  /// Why it is going, when the verb alone does not say.
  final String? reason;

  @override
  Preview preview() => Directory(directory).existsSync()
      ? Preview(verb: 'remove', target: directory, detail: reason)
      : Preview(verb: 'absent', target: directory);

  @override
  Future<Outcome> perform(StepContext context) async {
    final dir = Directory(directory);
    if (!dir.existsSync()) {
      return Outcome(verb: 'absent', target: directory);
    }
    dir.deleteSync(recursive: true);
    return Outcome(verb: 'remove', target: directory);
  }
}
