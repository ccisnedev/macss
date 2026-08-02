/// `macss requisition export-template [--path <dir>] [--lang <lang>]` — writes
/// the blank form.
///
/// The requisition template is handed to the Product Owner once, usually
/// rendered to PDF or DOCX. Producing it by scaffolding a throwaway requisition
/// would litter `docs/requisitions/` and move the active pointer, so it gets its
/// own command.
library;

import 'dart:io';

import 'package:cli_router/cli_router.dart';
import 'package:modular_cli_sdk/modular_cli_sdk.dart';
import 'package:path/path.dart' as p;

import '../../../templates/template_resolver.dart';

// ─── Input ──────────────────────────────────────────────────────────────────

class ExportTemplateInput extends Input {
  final String resolvedPath;
  final String lang;

  ExportTemplateInput({required this.resolvedPath, required this.lang});

  factory ExportTemplateInput.fromCliRequest(CliRequest req) {
    final raw = req.flagString('path', aliases: const ['p']);
    final cwd = Directory.current.path;
    return ExportTemplateInput(
      resolvedPath:
          raw == null ? cwd : (p.isAbsolute(raw) ? raw : p.join(cwd, raw)),
      lang: req.flagString('lang') ?? 'en',
    );
  }

  static final List<CliParam> params = [
    CliParam.string(
      'path',
      abbr: 'p',
      description: 'Directory to write the template into; defaults to the current one',
    ),
    CliParam.string(
      'lang',
      allowed: ['en', 'es'],
      defaultValue: 'en',
      description: 'Language of the template',
    ),
  ];

  @override
  List<CliParam> get schemaFields => params;

  @override
  Map<String, dynamic> toJson() => {'resolvedPath': resolvedPath, 'lang': lang};
}

// ─── Output ─────────────────────────────────────────────────────────────────

class ExportTemplateOutput extends Output {
  final String message;
  final String path;
  final int _exitCode;

  ExportTemplateOutput({
    required this.message,
    required this.path,
    int exitCode = ExitCode.ok,
  }) : _exitCode = exitCode;

  @override
  Map<String, dynamic> toJson() => {'message': message, 'path': path};

  @override
  int get exitCode => _exitCode;

  @override
  String? toText() => message;
}

// ─── Command ────────────────────────────────────────────────────────────────

class ExportTemplateCommand
    implements Command<ExportTemplateInput, ExportTemplateOutput> {
  @override
  final ExportTemplateInput input;

  final TemplateResolver resolver;

  /// Which artifact this exports — `requisition` or `specification`.
  final String artifact;

  ExportTemplateCommand(
    this.input, {
    required this.resolver,
    required this.artifact,
  });

  @override
  String? validate() {
    if (File(input.resolvedPath).existsSync()) {
      return '"${input.resolvedPath}" is a file, not a directory.';
    }
    return null;
  }

  @override
  Future<ExportTemplateOutput> execute() async {
    final resolution = resolver.resolve(artifact, lang: input.lang);
    final target = File(p.join(input.resolvedPath, '$artifact.md'));

    if (target.existsSync()) {
      return ExportTemplateOutput(
        message: '${target.path} already exists — not overwritten.',
        path: target.path,
        exitCode: ExitCode.conflict,
      );
    }

    target.parent.createSync(recursive: true);
    target.writeAsStringSync(resolution.content);

    final lines = [
      'exported  ${p.basename(target.path)} (${input.lang})',
      if (resolution.notice != null) 'note      ${resolution.notice}',
    ];
    return ExportTemplateOutput(message: lines.join('\n'), path: target.path);
  }
}
