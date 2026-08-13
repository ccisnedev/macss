/// `macss project adopt [--path <dir>] --plan|--apply` — brings an existing
/// project up to the MACSS canon.
///
/// This is the answer to "what if a project already exists and should adopt
/// MACSS?", which `project create` cannot give: `create` assumes an empty
/// directory, `adopt` works on one with history.
///
/// Follows the `--plan` / `--apply` convention of ADR 0007: neither is a
/// default, and a bare `adopt` is a usage error rather than a silent preview.
///
/// **`adopt` never deletes anything the project wrote.** It creates what the
/// canon requires and the project lacks, and never overwrites. Anything extra is
/// reported by `project check` as a warning and left alone: a `code/legacy/`
/// directory may be deliberate debt, and a tool has no context to decide that.
///
/// It does retire **`.gitignore` entries MACSS itself wrote and no longer
/// manages**. ADR 0004 said "adopt never deletes" flatly, and that was true
/// until the workspace began carrying its own ignore rule: while the project
/// root excludes `.macss/`, git never descends into it, so the inner rule is
/// dead letter and the project's configuration cannot be versioned. Leaving the
/// stale entry would mean shipping a directory that cannot do its job.
///
/// The licence is the same one `skill deploy` uses to prune its own namespace:
/// an entry under the MACSS header is machine-written output, not a user edit.
/// Nothing outside that header is touched, and the retirement appears in the
/// plan like every other change (ADR 0007).
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../assets.dart';
import '../../../src/gitignore.dart';
import '../../../src/project_config.dart';
import '../../../src/steps.dart';
import '../canon.dart';
import 'create.dart' show DeclareProjectLanguage;

// ─── Input ──────────────────────────────────────────────────────────────────

class ProjectAdoptInput extends Input {
  final String resolvedPath;

  /// Where the command was invoked — where the plan file goes. Not the same as
  /// [resolvedPath], which `--path` can point anywhere: a plan written into the
  /// target would be a change to the target, and `--plan` changes nothing.
  final String workingDirectory;

  /// The language this project's documents are written in.
  ///
  /// **Required, with no default.** Adopting the canon includes adopting this
  /// decision, and a fallback would be a choice nobody made (ADR 0009).
  final String? lang;

  ProjectAdoptInput({
    required this.resolvedPath,
    String? workingDirectory,
    this.lang,
  }) : workingDirectory = workingDirectory ?? resolvedPath;

  factory ProjectAdoptInput.fromCliRequest(
    CliRequest req, {
    String? workingDirectory,
  }) {
    final cwd = workingDirectory ?? Directory.current.path;
    final raw = req.flagString('path', aliases: const ['p']);
    return ProjectAdoptInput(
      resolvedPath:
          raw == null ? cwd : (p.isAbsolute(raw) ? raw : p.join(cwd, raw)),
      workingDirectory: cwd,
      lang: req.flagString('lang'),
    );
  }

  static final List<CliParam> params = [
    CliParam.string(
      'path',
      abbr: 'p',
      description: 'Project directory to adopt; defaults to the current one',
    ),
    // Adopting the canon includes adopting the decision about language, and
    // the declaration says so where a machine can read it.
    CliParam.string(
      'lang',
      required: true,
      allowed: ['en', 'es'],
      description:
          'Language of this project documents. There is no default: a fallback '
          'would be a choice nobody made',
    ),
  ];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {
        'resolvedPath': resolvedPath,
        'lang': lang,
      };
}

// ─── Output ─────────────────────────────────────────────────────────────────

class ProjectAdoptOutput extends Output {
  ProjectAdoptOutput({
    required this.created,
    required this.declared,
    required this.retired,
  });

  /// The canon files this stamped.
  final List<String> created;

  /// Whether the language was declared or re-declared.
  final bool declared;

  /// The `.gitignore` entries MACSS itself wrote and no longer manages.
  final List<String> retired;

  /// Whether anything changed at all. Nothing to adopt is the ordinary answer
  /// for a project already at the canon, not a failure.
  bool get applied => created.isNotEmpty || declared || retired.isNotEmpty;

  @override
  Map<String, dynamic> toJson() => {
    'created': created,
    'declared': declared,
    'retired': retired,
    'applied': applied,
  };

  @override
  int get exitCode => ExitCode.ok;

  @override
  String? toText() => applied
      ? [
          ...created.map((path) => '  created  $path'),
          if (declared) '  declared $projectConfigPath',
          ...retired.map((e) => '  retired  $e'),
          '',
          'Adopted. Run `macss project check` to see what still needs your '
              'judgement.',
        ].join('\n')
      : 'Nothing to adopt — every canonical file is already present.';
}

// ─── Command ────────────────────────────────────────────────────────────────

class ProjectAdoptCommand
    implements Command<ProjectAdoptInput, ProjectAdoptOutput> {
  @override
  final ProjectAdoptInput input;

  final Assets assets;
  final Approver approver;
  final DateTime Function() now;

  ProjectAdoptCommand(
    this.input, {
    required this.assets,
    Approver? approver,
    DateTime Function()? now,
  })  : approver = approver ?? ConsoleApprover().call,
        now = now ?? DateTime.now;

  @override
  String? validate() {
    if (File(input.resolvedPath).existsSync()) {
      return '"${input.resolvedPath}" is a file, not a project directory.';
    }
    if (!Directory(input.resolvedPath).existsSync()) {
      return 'No such directory: "${input.resolvedPath}".';
    }
    // `--lang` is declared required, so an invocation without it never reaches
    // this method.
    return null;
  }

  /// What the canon requires and the project lacks, then the language, then
  /// the entries MACSS itself wrote and no longer manages.
  ///
  /// The retirement is a step of its own rather than a side effect of applying:
  /// it is the one thing `adopt` removes, so it is the one thing a reader most
  /// needs the plan to have told them about.
  @override
  Future<List<Step>> steps() async {
    final root = input.resolvedPath;

    return [
      for (final file in missingCanonFiles(root))
        WriteFile(
          path: p.join(root, p.joinAll(file.path.split('/'))),
          contents: assets.loadString(file.template),
          shownAs: file.path,
        ),
      if (projectLanguage(root) != input.lang)
        DeclareProjectLanguage(root: root, language: input.lang!),
      for (final entry in retiredGitignoreEntriesIn(root))
        RetireGitignoreEntry(root: root, entry: entry),
    ];
  }

  @override
  ProjectAdoptOutput describe(Execution execution) => ProjectAdoptOutput(
    created: [
      for (final o in execution.outcomes)
        if (o.verb == 'create') o.target,
    ],
    declared: execution.outcomes.any((o) => o.verb == 'declare'),
    retired: [
      for (final o in execution.outcomes)
        if (o.verb == 'retire') o.target,
    ],
  );
}

// ─── Steps ──────────────────────────────────────────────────────────────────

/// Removes one `.gitignore` entry MACSS wrote and no longer manages.
///
/// The licence is the same one `skill deploy` uses to prune its own namespace:
/// an entry under the MACSS header is machine-written output, not a user edit.
/// Nothing outside that header is touched.
class RetireGitignoreEntry implements Step {
  RetireGitignoreEntry({required this.root, required this.entry});

  final String root;
  final String entry;

  @override
  Preview preview() => Preview(
    verb: 'retire',
    target: entry,
    detail: 'from $root/.gitignore — the workspace carries its own now, and '
        'git does not descend into an excluded directory',
  );

  @override
  Future<Outcome> perform(StepContext context) async {
    removeGitignoreEntries(root);
    return Outcome(verb: 'retire', target: entry);
  }
}
