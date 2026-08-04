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
/// **`adopt` never deletes.** It only creates what the canon requires and the
/// project lacks. Anything extra is reported by `project check` as a warning and
/// left alone: a `code/legacy/` directory may be deliberate debt, and a tool has
/// no context to decide that.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../assets.dart';
import '../../../src/plan_apply.dart';
import '../canon.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class ProjectAdoptInput extends Input {
  final String resolvedPath;

  /// Where the command was invoked — where the plan file goes. Not the same as
  /// [resolvedPath], which `--path` can point anywhere: a plan written into the
  /// target would be a change to the target, and `--plan` changes nothing.
  final String workingDirectory;

  final ChangeFlags flags;

  ProjectAdoptInput({
    required this.resolvedPath,
    required this.flags,
    String? workingDirectory,
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
      flags: ChangeFlags.fromCliRequest(req),
    );
  }

  static final List<CliParam> params = [
    CliParam.string(
      'path',
      abbr: 'p',
      description: 'Project directory to adopt; defaults to the current one',
    ),
    ...ChangeFlags.params,
  ];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {
        'resolvedPath': resolvedPath,
        'plan': flags.plan,
        'apply': flags.apply,
        'autoapprove': flags.autoapprove,
      };
}

// ─── Output ─────────────────────────────────────────────────────────────────

class ProjectAdoptOutput extends Output {
  final String message;
  final List<String> created;
  final bool applied;

  /// Where the plan was written, when the caller asked for `--plan`.
  final String? planPath;

  /// True when `--apply` reached a human who said no. Not an error in the
  /// command — the answer was taken and honoured — but a non-zero exit, so a
  /// script cannot mistake a refusal for a change.
  final bool declined;

  ProjectAdoptOutput({
    required this.message,
    required this.created,
    required this.applied,
    this.planPath,
    this.declined = false,
  });

  @override
  Map<String, dynamic> toJson() => {
        'message': message,
        'created': created,
        'applied': applied,
        'planPath': planPath,
        'declined': declined,
      };

  @override
  int get exitCode => declined ? ExitCode.genericError : ExitCode.ok;

  @override
  String? toText() => message;
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
    return input.flags.validate();
  }

  @override
  Future<ProjectAdoptOutput> execute() async {
    final root = input.resolvedPath;
    final missing = missingCanonFiles(root);

    // Nothing to change means nothing to plan. Writing an empty plan file
    // would leave an artifact saying "no artifact was needed".
    if (missing.isEmpty) {
      return ProjectAdoptOutput(
        message: 'Nothing to adopt — every canonical file is already present.',
        created: const [],
        applied: false,
      );
    }

    // The one rendering, used by both modes. Rule 6 of ADR 0007: what `--apply`
    // shows and what `--plan` writes are the same computation, rendered the
    // same way. Two renderings would drift, and drift between the plan and the
    // change is the whole failure this convention exists to prevent.
    final body = [
      '${missing.length} file(s) would be created in $root:',
      '',
      ...missing.map((f) => '  create   ${f.path}'),
      '',
      'Nothing else is touched: adopt never removes or overwrites. '
          'Run `macss project check` for what needs your judgement.',
    ].join('\n');

    final decision = await ChangeGate(
      flags: input.flags,
      approver: approver,
      now: now,
    ).decide(
      command: 'project adopt',
      workingDirectory: input.workingDirectory,
      body: body,
    );

    if (!decision.proceed) {
      return ProjectAdoptOutput(
        message: decision.message!,
        created: const [],
        applied: false,
        planPath: decision.planPath,
        declined: decision.blocked,
      );
    }

    final created = <String>[];
    for (final file in missing) {
      final target = File(p.join(root, p.joinAll(file.path.split('/'))));
      target.parent.createSync(recursive: true);
      target.writeAsStringSync(assets.loadString(file.template));
      created.add(file.path);
    }

    final lines = [
      ...created.map((path) => '  created  $path'),
      '',
      'Adopted. Run `macss project check` to see what still needs your '
          'judgement.',
    ];
    return ProjectAdoptOutput(
      message: lines.join('\n'),
      created: created,
      applied: true,
    );
  }
}
