/// Where MACSS files the plans that `--plan` produces.
///
/// Everything else that used to live here — the `--plan` / `--apply` flags,
/// their rules, the approval, the gate — moved into `modular_cli_sdk` 0.4.0,
/// which declares and applies them for every command. What is left is the one
/// decision the SDK deliberately does not take: whether a plan is kept on disk,
/// and where.
///
/// The plan is the point of `--plan`: a preview that only ever existed as
/// terminal output could not be attached to an issue, diffed against a later
/// run, or read by someone who was not at the keyboard.
///
/// `.macss/` is the local workspace the CLI already owns and already
/// git-ignores. A plan records an intention, not history — committing plans
/// would leave a second, staler description of every change beside the change.
///
/// Two rules govern where it goes, and both used to be a command's business.
///
/// **It is written where the command was invoked, never inside the directory it
/// targets.** Writing it into the target would itself be a change, which is the
/// one thing `--plan` promises not to make — and for `project create` the
/// target does not exist yet, so planning would create the very directory it
/// says it would only create under `--apply`. This was honoured by each command
/// passing the right directory, and `requisition export-template --path X`
/// passed the target: it filed its plan inside the very directory the caller
/// had only asked to receive a template. A sink registered once on the CLI has
/// no per-command directory to get wrong.
///
/// **It is written only inside a MACSS project.** See [macssPlanSink].
library;

import 'dart:io';

import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import 'project_config.dart';
import 'workspace_dir.dart';

/// Where plans live, relative to the directory the command was invoked in.
const planDirectory = '$workspaceDirName/plans';

/// The [PlanSink] MACSS registers on its `ModularCli`.
///
/// **A plan is filed only inside a MACSS project.** Five commands are designed
/// to run where no project exists — `requisition export-template`, `skill
/// deploy`, `skill clean`, `upgrade` and `uninstall` — and `export-template`
/// says so in its own contract: `--lang` is required there precisely because
/// "this runs where no project need exist, so there is nothing to derive it
/// from". Filing a plan would answer that by creating `.macss/` in a directory
/// whose owner asked for a blank form and nothing else.
///
/// So outside a project `--plan` shows the plan and files nothing. It is not a
/// lesser answer: the plan is on the terminal either way, and `--json` gives it
/// as data. What is lost is a file nobody asked for, in a folder MACSS does not
/// own.
///
/// The marker is the project's configuration, not the workspace directory. A
/// directory only has `.macss/` because some command put it there, and this
/// rule exists to stop that happening by accident; `config.yaml` is what a
/// human decided.
///
/// [now] and [workingDirectory] are seams for the tests: a plan's name carries
/// a timestamp, and a suite that cannot fix the clock cannot assert the name.
PlanSink macssPlanSink({DateTime Function()? now, String? workingDirectory}) {
  final clock = now ?? DateTime.now;
  return (plan) {
    final root = workingDirectory ?? Directory.current.path;
    if (!isMacssProject(root)) return null;
    return PlanFile.write(workingDirectory: root, plan: plan, now: clock());
  };
}

/// Whether [root] is a MACSS project — the question the sink asks before it
/// writes anything.
bool isMacssProject(String root) =>
    File(p.join(root, projectConfigPath)).existsSync();

/// Writes the plan artifact under `.macss/plans/`.
class PlanFile {
  /// Writes [plan] and returns the path written.
  ///
  /// [now] is injected so the name is deterministic under test; the timestamp
  /// is what keeps successive plans for the same command from overwriting each
  /// other, which is what makes two runs comparable.
  static String write({
    required String workingDirectory,
    required PlanDocument plan,
    required DateTime now,
  }) {
    // Through `ensureWorkspace`, so a plan written in a project that never
    // opened a requisition still lands in a workspace that ignores itself.
    final dir = Directory(
      p.join(ensureWorkspace(workingDirectory).path, 'plans'),
    )..createSync(recursive: true);

    final file = File(p.join(dir.path, '${_stamp(now)}-${_slug(plan.route)}.md'));
    file.writeAsStringSync(render(plan: plan, now: now));
    return file.path;
  }

  /// The plan document, rendered.
  ///
  /// Written out in full rather than referring to the terminal that produced
  /// it: the reader of a plan is, by design, someone who did not run it.
  ///
  /// The steps are listed one per line, which is what the SDK renders too — but
  /// re-rendered here rather than embedding `plan.text`, because that carries a
  /// heading meant for a terminal and this document has its own.
  static String render({required PlanDocument plan, required DateTime now}) => [
    '# Plan — `macss ${plan.route}`',
    '',
    '| | |',
    '| --- | --- |',
    '| Command | `macss ${plan.route} --plan` |',
    '| Written | ${now.toIso8601String()} |',
    '',
    '## What would change',
    '',
    if (plan.previews.isEmpty)
      'Nothing would change.'
    else ...[
      '```',
      ...plan.previews.map(_line),
      '```',
    ],
    '',
    '---',
    '',
    'Nothing was changed. Re-run with `--apply` to apply this plan, or',
    '`--apply --autoapprove` where nobody is at the keyboard.',
    '',
  ].join('\n');

  /// `create   docs/requisition.md  (number: known once this runs)`
  static String _line(Preview preview) {
    final line = '${preview.verb.padRight(8)} ${preview.target}';
    final notes = [
      if (preview.detail != null) preview.detail!,
      for (final name in preview.pending) '$name: known once this runs',
    ];
    return notes.isEmpty ? line : '$line  (${notes.join('; ')})';
  }

  static String _stamp(DateTime t) => [
    t.year.toString().padLeft(4, '0'),
    t.month.toString().padLeft(2, '0'),
    t.day.toString().padLeft(2, '0'),
    '-',
    t.hour.toString().padLeft(2, '0'),
    t.minute.toString().padLeft(2, '0'),
    t.second.toString().padLeft(2, '0'),
  ].join();

  static String _slug(String route) => route.trim().replaceAll(' ', '-');
}
