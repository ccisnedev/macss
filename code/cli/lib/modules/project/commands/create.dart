/// `macss project create --path <dir>` — scaffolds a MACSS project.
///
/// Stamps the canon defined in `canon.dart`, the same definition
/// `project check` verifies and `project adopt` fills. Idempotent: an existing
/// file is never overwritten.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../assets.dart';
import '../canon.dart';

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
      return '--path is required. Usage: macss project create --path=<dir>';
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

    final dir = Directory(root);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
      steps.add('created  $root');
    } else {
      steps.add('exists   $root');
    }

    for (final file in canonFiles) {
      steps.add(_stamp(root, file));
    }

    if (steps.every((s) => s.startsWith('exists'))) {
      return CreateOutput(
        message: 'Project already initialized at $root\n${steps.join('\n')}',
        created: false,
      );
    }

    return CreateOutput(message: steps.join('\n'), created: true);
  }

  String _stamp(String root, CanonFile file) {
    final target = File(p.join(root, p.joinAll(file.path.split('/'))));
    if (target.existsSync()) return 'exists   ${file.path}';

    target.parent.createSync(recursive: true);
    target.writeAsStringSync(assets.loadString(file.template));
    return 'created  ${file.path}';
  }
}
