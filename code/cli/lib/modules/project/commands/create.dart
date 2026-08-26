/// `macss project create --path <dir> --plan|--apply` — scaffolds a MACSS
/// project.
///
/// Stamps the canon defined in `canon.dart`, the same definition
/// `project check` verifies and `project adopt` fills. Idempotent: an existing
/// file is never overwritten.
///
/// Follows the `--plan` / `--apply` convention of ADR 0007. The plan is written
/// where the command was invoked, never inside `--path`: that directory is
/// usually the thing `create` would bring into existence, so planning there
/// would make the very change it says it would not.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../assets.dart';
import '../../../src/project_config.dart';
import '../../../src/steps.dart';
import '../canon.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class CreateInput extends Input {
  final String? resolvedPath;
  final String workingDirectory;

  /// The language this project's documents will be written in.
  ///
  /// **Required, with no default.** Creating a project is the moment the choice
  /// is made, so it is the moment it must be stated; a sensible fallback would
  /// still be a choice nobody made (ADR 0009).
  final String? lang;

  CreateInput({
    required this.resolvedPath,
    required this.workingDirectory,
    this.lang,
  });

  factory CreateInput.fromCliRequest(
    CliRequest req, {
    String? workingDirectory,
  }) {
    final rawPath = req.flagString('path', aliases: const ['p']);
    workingDirectory ??= Directory.current.path;

    return CreateInput(
      resolvedPath: rawPath == null
          ? null
          : (p.isAbsolute(rawPath)
                ? rawPath
                : p.join(workingDirectory, rawPath)),
      workingDirectory: workingDirectory,
      lang: req.flagString('lang'),
    );
  }

  /// Declared contract: `--path` / `-p`, plus the convention's three flags.
  /// Declaring them rejects any other flag at parse time and publishes the
  /// options in help.
  static final List<CliParam> params = [
    // Declared required rather than checked in `validate`. The declaration is
    // the contract this CLI publishes, and a rule enforced only in prose is one
    // `help --json` reports the opposite of — to the machine that reads it.
    CliParam.string(
      'path',
      abbr: 'p',
      required: true,
      description: 'Directory to scaffold the MACSS project into',
    ),
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
        'workingDirectory': workingDirectory,
        'lang': lang,
      };
}

// ─── Output ─────────────────────────────────────────────────────────────────

class CreateOutput extends Output {
  CreateOutput({required this.root, required this.did});

  final String root;

  /// One `verb  target` line per step that ran, in order.
  final List<({String verb, String target})> did;

  /// Whether anything was actually stamped. A second run creates nothing, and
  /// that is the ordinary answer rather than a failure.
  bool get created => did.any((s) => s.verb == 'create');

  @override
  Map<String, dynamic> toJson() => {
    'root': root,
    'created': created,
    'did': {for (final s in did) s.target: s.verb},
  };

  @override
  int get exitCode => ExitCode.ok;

  @override
  String? toText() => created
      ? did.map((s) => '${s.verb.padRight(8)} ${s.target}').join('\n')
      : [
          'Project already initialized at $root',
          ...did.map((s) => '${s.verb.padRight(8)} ${s.target}'),
        ].join('\n');
}

// ─── Command ────────────────────────────────────────────────────────────────

class CreateCommand implements Command<CreateInput, CreateOutput> {
  @override
  final CreateInput input;

  final Assets assets;

  CreateCommand(this.input, {required this.assets});

  @override
  String? validate() {
    // Neither `--path` nor `--lang` is checked here: both are declared
    // required, so an invocation missing either is refused before this runs.
    return null;
  }

  /// The root, then the canon, then the configuration.
  ///
  /// `create` is idempotent, so the answer is per file: stamp it, or leave the
  /// one already there — and each step decides that for itself, once. The list
  /// used to be built twice, as a preview and again as the work.
  @override
  Future<List<Step>> steps() async {
    final root = input.resolvedPath!;

    if (File(root).existsSync()) {
      throw CommandException(
        code: 'PATH_IS_A_FILE',
        message: 'Error: "$root" is an existing file, not a directory.',
        exitCode: 2,
      );
    }

    return [
      EnsureDirectory(root),
      // `createFiles`, not `canonFiles`: a new project opens on the common
      // shape (infra/db/api/app) as well as on the canon. `check` does not ask
      // for that shape and `adopt` does not add it, so a project that has no
      // API deletes the directory (ADR 0011).
      for (final file in createFiles)
        WriteFile(
          path: p.join(root, p.joinAll(file.path.split('/'))),
          contents: assets.loadString(file.template),
          shownAs: file.path,
        ),
      DeclareProjectLanguage(root: root, language: input.lang!),
    ];
  }

  @override
  CreateOutput describe(Execution execution) => CreateOutput(
    root: input.resolvedPath!,
    did: [
      for (final o in execution.outcomes) (verb: o.verb, target: o.target),
    ],
  );
}

// ─── Steps ──────────────────────────────────────────────────────────────────

/// Creates a directory, or reports the one already there.
class EnsureDirectory implements Step {
  EnsureDirectory(this.path);

  final String path;

  @override
  Preview preview() => Directory(path).existsSync()
      ? Preview(verb: 'exists', target: path)
      : Preview(verb: 'create', target: path);

  @override
  Future<Outcome> perform(StepContext context) async {
    if (Directory(path).existsSync()) {
      return Outcome(verb: 'exists', target: path);
    }
    Directory(path).createSync(recursive: true);
    return Outcome(verb: 'create', target: path);
  }
}

/// Writes the project's own configuration.
///
/// The one thing in `.macss/` that is versioned: the language must be the same
/// for everyone who clones. Rewritten rather than kept — unlike the canon,
/// which is the author's to edit, this is the answer the invocation gave.
class DeclareProjectLanguage implements Step {
  DeclareProjectLanguage({required this.root, required this.language});

  final String root;
  final String language;

  @override
  Preview preview() => Preview(
    verb: 'declare',
    target: projectConfigPath,
    detail: 'language: $language',
  );

  @override
  Future<Outcome> perform(StepContext context) async {
    writeProjectConfig(root, language: language);
    return Outcome(
      verb: 'declare',
      target: projectConfigPath,
      values: {'language': language},
    );
  }
}
