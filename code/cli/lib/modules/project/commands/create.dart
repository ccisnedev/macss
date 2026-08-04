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
import '../../../src/plan_apply.dart';
import '../canon.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class CreateInput extends Input {
  final String? resolvedPath;
  final String workingDirectory;
  final ChangeFlags flags;

  CreateInput({
    required this.resolvedPath,
    required this.workingDirectory,
    required this.flags,
  });

  factory CreateInput.fromCliRequest(CliRequest req) {
    final rawPath = req.flagString('path', aliases: const ['p']);
    final workingDirectory = Directory.current.path;
    final flags = ChangeFlags.fromCliRequest(req);

    if (rawPath == null) {
      return CreateInput(
        resolvedPath: null,
        workingDirectory: workingDirectory,
        flags: flags,
      );
    }

    final resolved =
        p.isAbsolute(rawPath) ? rawPath : p.join(workingDirectory, rawPath);

    return CreateInput(
      resolvedPath: resolved,
      workingDirectory: workingDirectory,
      flags: flags,
    );
  }

  /// Declared contract: `--path` / `-p`, plus the convention's three flags.
  /// Declaring them rejects any other flag at parse time and publishes the
  /// options in help.
  static final List<CliParam> params = [
    CliParam.string(
      'path',
      abbr: 'p',
      description: 'Directory to scaffold the MACSS project into',
    ),
    ...ChangeFlags.params,
  ];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {
        'resolvedPath': resolvedPath,
        'workingDirectory': workingDirectory,
        'plan': flags.plan,
        'apply': flags.apply,
        'autoapprove': flags.autoapprove,
      };
}

// ─── Output ─────────────────────────────────────────────────────────────────

class CreateOutput extends Output {
  final String message;
  final bool created;
  final String? planPath;
  final int _exitCode;

  CreateOutput({
    required this.message,
    required this.created,
    this.planPath,
    int exitCode = ExitCode.ok,
  }) : _exitCode = exitCode;

  @override
  Map<String, dynamic> toJson() =>
      {'message': message, 'created': created, 'planPath': planPath};

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
  final Approver? approver;
  final DateTime Function()? now;

  CreateCommand(this.input, {required this.assets, this.approver, this.now});

  @override
  String? validate() {
    if (input.resolvedPath == null || input.resolvedPath!.isEmpty) {
      return '--path is required. Usage: macss project create --path=<dir>';
    }
    return input.flags.validate();
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

    // What would happen, decided before anything happens. `create` is
    // idempotent, so the answer is per file: stamp it, or leave the one that
    // is already there.
    final absent = canonFiles.where((f) => !_target(root, f).existsSync());
    final rootExists = Directory(root).existsSync();

    if (absent.isEmpty && rootExists) {
      return CreateOutput(
        message: 'Project already initialized at $root\n'
            '${[
          'exists   $root',
          ...canonFiles.map((f) => 'exists   ${f.path}')
        ].join('\n')}',
        created: false,
      );
    }

    final body = [
      if (!rootExists) '  create   $root' else '  exists   $root',
      ...canonFiles.map((f) => absent.contains(f)
          ? '  create   ${f.path}'
          : '  exists   ${f.path}'),
      '',
      'An existing file is never overwritten.',
    ].join('\n');

    final decision = await ChangeGate(
      flags: input.flags,
      approver: approver,
      now: now,
    ).decide(
      command: 'project create',
      workingDirectory: input.workingDirectory,
      body: body,
    );

    if (!decision.proceed) {
      return CreateOutput(
        message: decision.message!,
        created: false,
        planPath: decision.planPath,
        exitCode: decision.blocked ? ExitCode.genericError : ExitCode.ok,
      );
    }

    final steps = <String>[];
    if (!rootExists) {
      Directory(root).createSync(recursive: true);
      steps.add('created  $root');
    } else {
      steps.add('exists   $root');
    }
    for (final file in canonFiles) {
      steps.add(_stamp(root, file));
    }

    return CreateOutput(message: steps.join('\n'), created: true);
  }

  File _target(String root, CanonFile file) =>
      File(p.join(root, p.joinAll(file.path.split('/'))));

  String _stamp(String root, CanonFile file) {
    final target = _target(root, file);
    if (target.existsSync()) return 'exists   ${file.path}';

    target.parent.createSync(recursive: true);
    target.writeAsStringSync(assets.loadString(file.template));
    return 'created  ${file.path}';
  }
}
