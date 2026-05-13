/// `macss create <path>` — scaffolds a MACSS project at the given path.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../assets.dart';

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

    // 2. Code subdirectories
    final subdirectories = [
      'code/infra',
      'code/db',
      'code/api',
      'code/ui',
    ];
    for (final dir in subdirectories) {
      _ensureDir(p.join(root, p.joinAll(dir.split('/'))), dir, steps);
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
