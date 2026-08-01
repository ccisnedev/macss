/// `macss project adopt [--path <dir>] [--plan|--apply]` — brings an existing
/// project up to the MACSS canon.
///
/// This is the answer to "what if a project already exists and should adopt
/// MACSS?", which `project create` cannot give: `create` assumes an empty
/// directory, `adopt` works on one with history.
///
/// Previews by default, following the same `--plan` / `--apply` convention as
/// `macss issue publish`.
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
import '../canon.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class ProjectAdoptInput extends Input {
  final String resolvedPath;
  final bool apply;

  ProjectAdoptInput({required this.resolvedPath, required this.apply});

  factory ProjectAdoptInput.fromCliRequest(CliRequest req) {
    final raw = req.flagString('path', aliases: const ['p']);
    final cwd = Directory.current.path;
    return ProjectAdoptInput(
      resolvedPath:
          raw == null ? cwd : (p.isAbsolute(raw) ? raw : p.join(cwd, raw)),
      apply: req.flagBool('apply'),
    );
  }

  /// `--plan` is the default, so it is not declared: passing `--apply` is the
  /// deliberate act. A bare `adopt` previews and writes nothing.
  static final List<CliParam> params = [
    CliParam.string(
      'path',
      abbr: 'p',
      description: 'Project directory to adopt; defaults to the current one',
    ),
    CliParam.boolean(
      'apply',
      description: 'Create the missing files; without it, only previews',
    ),
  ];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() =>
      {'resolvedPath': resolvedPath, 'apply': apply};
}

// ─── Output ─────────────────────────────────────────────────────────────────

class ProjectAdoptOutput extends Output {
  final String message;
  final List<String> created;
  final bool applied;

  ProjectAdoptOutput({
    required this.message,
    required this.created,
    required this.applied,
  });

  @override
  Map<String, dynamic> toJson() =>
      {'message': message, 'created': created, 'applied': applied};

  @override
  int get exitCode => ExitCode.ok;

  @override
  String? toText() => message;
}

// ─── Command ────────────────────────────────────────────────────────────────

class ProjectAdoptCommand
    implements Command<ProjectAdoptInput, ProjectAdoptOutput> {
  @override
  final ProjectAdoptInput input;

  final Assets assets;

  ProjectAdoptCommand(this.input, {required this.assets});

  @override
  String? validate() {
    if (File(input.resolvedPath).existsSync()) {
      return '"${input.resolvedPath}" is a file, not a project directory.';
    }
    if (!Directory(input.resolvedPath).existsSync()) {
      return 'No such directory: "${input.resolvedPath}".';
    }
    return null;
  }

  @override
  Future<ProjectAdoptOutput> execute() async {
    final root = input.resolvedPath;
    final missing = missingCanonFiles(root);

    if (missing.isEmpty) {
      return ProjectAdoptOutput(
        message: 'Nothing to adopt — every canonical file is already present.',
        created: const [],
        applied: false,
      );
    }

    if (!input.apply) {
      final lines = [
        'Plan — ${missing.length} file(s) would be created in $root:',
        ...missing.map((f) => '  create   ${f.path}'),
        '',
        'Nothing else is touched: adopt never removes or overwrites. '
            'Run `macss project check` for what needs your judgement.',
        '',
        'Re-run with --apply to create them.',
      ];
      return ProjectAdoptOutput(
        message: lines.join('\n'),
        created: const [],
        applied: false,
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
