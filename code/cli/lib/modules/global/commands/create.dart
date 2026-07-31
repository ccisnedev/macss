/// `macss create <path>` — scaffolds a MACSS project at the given path.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../assets.dart';
import '../../skill/deployer.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class CreateInput extends Input {
  final String? resolvedPath;
  final String workingDirectory;

  CreateInput({required this.resolvedPath, required this.workingDirectory});

  factory CreateInput.fromCliRequest(CliRequest req) {
    final rawPath = req.flagString('path', aliases: const ['p']);
    final workingDirectory = Directory.current.path;

    if (rawPath == null) {
      return CreateInput(
        resolvedPath: null,
        workingDirectory: workingDirectory,
      );
    }

    final resolved =
        p.isAbsolute(rawPath) ? rawPath : p.join(workingDirectory, rawPath);

    return CreateInput(
      resolvedPath: resolved,
      workingDirectory: workingDirectory,
    );
  }

  /// Declared contract: a single `--path` / `-p` option. Declaring it rejects
  /// any other flag at parse time and publishes the option in help.
  static final List<CliParam> params = [
    CliParam.string(
      'path',
      abbr: 'p',
      description: 'Directory to scaffold the MACSS project into',
    ),
  ];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {
    'resolvedPath': resolvedPath,
    'workingDirectory': workingDirectory,
  };
}

// ─── Output ─────────────────────────────────────────────────────────────────

class CreateOutput extends Output {
  final String message;
  final bool created;
  final int _exitCode;

  CreateOutput({
    required this.message,
    required this.created,
    int exitCode = ExitCode.ok,
  }) : _exitCode = exitCode;

  @override
  Map<String, dynamic> toJson() => {'message': message, 'created': created};

  @override
  int get exitCode => _exitCode;

  @override
  String? toText() => message;
}

// ─── Command ────────────────────────────────────────────────────────────────

class CreateCommand implements Command<CreateInput, CreateOutput> {
  @override
  final CreateInput input;

  final Assets assets;

  CreateCommand(this.input, {required this.assets});

  @override
  String? validate() {
    if (input.resolvedPath == null || input.resolvedPath!.isEmpty) {
      return '--path is required. Usage: macss create --path=<dir>';
    }
    return null;
  }

  @override
  Future<CreateOutput> execute() async {
    final root = input.resolvedPath!;

    // Guard: path must not be an existing file.
    if (File(root).existsSync()) {
      return CreateOutput(
        message: 'Error: "$root" is an existing file, not a directory.',
        created: false,
        exitCode: 2,
      );
    }

    final steps = <String>[];

    // 1. Root directory
    _ensureDir(root, root, steps);

    // 2. Module anchors — each README is the architectural signal of its module
    //    and makes the directory survive the first commit (git ignores empty dirs).
    final moduleAnchors = {
      'code/infra/README.md': 'templates/project-base/code/infra/README.md',
      'code/db/README.md': 'templates/project-base/code/db/README.md',
      'code/api/README.md': 'templates/project-base/code/api/README.md',
      'code/app/README.md': 'templates/project-base/code/app/README.md',
    };

    for (final entry in moduleAnchors.entries) {
      _ensureFileFromTemplate(
        p.join(root, p.joinAll(entry.key.split('/'))),
        entry.value,
        entry.key,
        steps,
      );
    }

    // 3. Docs from templates
    final templates = {
      'docs/adr/0001-record-architecture-decisions.md': 'templates/project-base/docs/adr/0001-record-architecture-decisions.md',
      'docs/architecture.md': 'templates/project-base/docs/architecture.md',
      'docs/roadmap.md': 'templates/project-base/docs/roadmap.md',
    };

    for (final entry in templates.entries) {
      _ensureFileFromTemplate(
        p.join(root, p.joinAll(entry.key.split('/'))),
        entry.value,
        entry.key,
        steps,
      );
    }

    // 4. Root files from templates
    final rootFiles = {
      'README.md': 'templates/project-base/README.md',
      '.gitignore': 'templates/project-base/.gitignore',
      '.gitattributes': 'templates/project-base/.gitattributes',
    };

    for (final entry in rootFiles.entries) {
      _ensureFileFromTemplate(
        p.join(root, entry.key),
        entry.value,
        entry.key,
        steps,
      );
    }

    // 5. Lifecycle skills — the project arrives with them in place. `.skills/`
    //    is git-ignored (see the project-base .gitignore), so this is local,
    //    reproducible output, refreshable with `macss skill deploy`.
    if (assets.directoryExists('skills')) {
      steps.addAll(
        deploySkills(
          assets: assets,
          targetDir: p.join(root, '.skills'),
          display: '.skills',
        ),
      );
    }

    if (steps.every((s) => s.startsWith('exists'))) {
      return CreateOutput(
        message: 'Project already initialized at $root\n${steps.join('\n')}',
        created: false,
      );
    }

    return CreateOutput(message: steps.join('\n'), created: true);
  }

  void _ensureDir(String path, String display, List<String> steps) {
    final dir = Directory(path);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
      steps.add('created  $display');
    } else {
      steps.add('exists   $display');
    }
  }

  void _ensureFileFromTemplate(
    String targetPath,
    String templateRelative,
    String display,
    List<String> steps,
  ) {
    final file = File(targetPath);
    if (!file.existsSync()) {
      Directory(p.dirname(targetPath)).createSync(recursive: true);
      final content = assets.loadString(templateRelative);
      file.writeAsStringSync(content);
      steps.add('created  $display');
    } else {
      steps.add('exists   $display');
    }
  }
}
